package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type App struct {
	db *pgxpool.Pool
}

type Parent struct {
	ID            int64     `json:"id"`
	AccountNumber int64     `json:"account_number"`
	Status        string    `json:"status"`
	CreatedAt     time.Time `json:"created_at"`
	Payload       string    `json:"payload"`
}

type Child struct {
	ID             int64  `json:"id"`
	ParentID       int64  `json:"parent_id"`
	SequenceNumber int32  `json:"sequence_number"`
	ValueNumber    int32  `json:"value_number"`
	Payload        string `json:"payload"`
}

type Event struct {
	ID        int64     `json:"id"`
	ParentID  int64     `json:"parent_id"`
	EventType string    `json:"event_type"`
	EventTime time.Time `json:"event_time"`
	Payload   string    `json:"payload"`
}

type Bundle struct {
	Parent   Parent  `json:"parent"`
	Children []Child `json:"children"`
	Events   []Event `json:"events"`
}

type EventRequest struct {
	ID        int64  `json:"id"`
	ParentID  int64  `json:"parent_id"`
	EventType string `json:"event_type"`
	Payload   string `json:"payload"`
}

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("json encode error: %v", err)
	}
}

func pathID(path, prefix string) (int64, error) {
	value := strings.TrimPrefix(path, prefix)

	if value == path || value == "" {
		return 0, errors.New("invalid id")
	}

	if strings.Contains(value, "/") {
		value = strings.Split(value, "/")[0]
	}

	return strconv.ParseInt(value, 10, 64)
}

func (a *App) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := a.db.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "database unavailable",
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
	})
}

func (a *App) parent(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r.URL.Path, "/parent/")
	if err != nil {
		http.Error(w, "invalid parent id", http.StatusBadRequest)
		return
	}

	var p Parent

	err = a.db.QueryRow(
		r.Context(),
		`
		SELECT id, account_number, status, created_at, payload
		FROM benchmark_parent
		WHERE id = $1
		`,
		id,
	).Scan(
		&p.ID,
		&p.AccountNumber,
		&p.Status,
		&p.CreatedAt,
		&p.Payload,
	)

	if err != nil {
		http.Error(w, "parent not found", http.StatusNotFound)
		return
	}

	writeJSON(w, http.StatusOK, p)
}

func (a *App) children(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r.URL.Path, "/parent/")
	if err != nil {
		http.Error(w, "invalid parent id", http.StatusBadRequest)
		return
	}

	rows, err := a.db.Query(
		r.Context(),
		`
		SELECT id, parent_id, sequence_number, value_number, payload
		FROM benchmark_child
		WHERE parent_id = $1
		ORDER BY id
		`,
		id,
	)

	if err != nil {
		http.Error(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	children := make([]Child, 0, 10)

	for rows.Next() {
		var c Child

		if err := rows.Scan(
			&c.ID,
			&c.ParentID,
			&c.SequenceNumber,
			&c.ValueNumber,
			&c.Payload,
		); err != nil {
			http.Error(w, "scan failed", http.StatusInternalServerError)
			return
		}

		children = append(children, c)
	}

	writeJSON(w, http.StatusOK, children)
}

func (a *App) events(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r.URL.Path, "/parent/")
	if err != nil {
		http.Error(w, "invalid parent id", http.StatusBadRequest)
		return
	}

	rows, err := a.db.Query(
		r.Context(),
		`
		SELECT id, parent_id, event_type, event_time, payload
		FROM benchmark_event
		WHERE parent_id = $1
		ORDER BY event_time DESC, id DESC
		LIMIT 20
		`,
		id,
	)

	if err != nil {
		http.Error(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	events := make([]Event, 0, 20)

	for rows.Next() {
		var e Event

		if err := rows.Scan(
			&e.ID,
			&e.ParentID,
			&e.EventType,
			&e.EventTime,
			&e.Payload,
		); err != nil {
			http.Error(w, "scan failed", http.StatusInternalServerError)
			return
		}

		events = append(events, e)
	}

	writeJSON(w, http.StatusOK, events)
}

func (a *App) bundle(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r.URL.Path, "/parent/")
	if err != nil {
		http.Error(w, "invalid parent id", http.StatusBadRequest)
		return
	}

	var result Bundle

	err = a.db.QueryRow(
		r.Context(),
		`
		SELECT id, account_number, status, created_at, payload
		FROM benchmark_parent
		WHERE id = $1
		`,
		id,
	).Scan(
		&result.Parent.ID,
		&result.Parent.AccountNumber,
		&result.Parent.Status,
		&result.Parent.CreatedAt,
		&result.Parent.Payload,
	)

	if err != nil {
		http.Error(w, "parent not found", http.StatusNotFound)
		return
	}

	childRows, err := a.db.Query(
		r.Context(),
		`
		SELECT id, parent_id, sequence_number, value_number, payload
		FROM benchmark_child
		WHERE parent_id = $1
		ORDER BY id
		`,
		id,
	)

	if err != nil {
		http.Error(w, "child query failed", http.StatusInternalServerError)
		return
	}

	result.Children = make([]Child, 0, 10)

	for childRows.Next() {
		var c Child

		if err := childRows.Scan(
			&c.ID,
			&c.ParentID,
			&c.SequenceNumber,
			&c.ValueNumber,
			&c.Payload,
		); err != nil {
			childRows.Close()
			http.Error(w, "child scan failed", http.StatusInternalServerError)
			return
		}

		result.Children = append(result.Children, c)
	}

	childRows.Close()

	eventRows, err := a.db.Query(
		r.Context(),
		`
		SELECT id, parent_id, event_type, event_time, payload
		FROM benchmark_event
		WHERE parent_id = $1
		ORDER BY event_time DESC, id DESC
		LIMIT 20
		`,
		id,
	)

	if err != nil {
		http.Error(w, "event query failed", http.StatusInternalServerError)
		return
	}

	result.Events = make([]Event, 0, 20)

	for eventRows.Next() {
		var e Event

		if err := eventRows.Scan(
			&e.ID,
			&e.ParentID,
			&e.EventType,
			&e.EventTime,
			&e.Payload,
		); err != nil {
			eventRows.Close()
			http.Error(w, "event scan failed", http.StatusInternalServerError)
			return
		}

		result.Events = append(result.Events, e)
	}

	eventRows.Close()

	writeJSON(w, http.StatusOK, result)
}

func (a *App) accountParents(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r.URL.Path, "/account/")
	if err != nil {
		http.Error(w, "invalid account id", http.StatusBadRequest)
		return
	}

	rows, err := a.db.Query(
		r.Context(),
		`
		SELECT id, account_number, status, created_at, payload
		FROM benchmark_parent
		WHERE account_number = $1
		ORDER BY id
		LIMIT 50
		`,
		id,
	)

	if err != nil {
		http.Error(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	parents := make([]Parent, 0, 50)

	for rows.Next() {
		var p Parent

		if err := rows.Scan(
			&p.ID,
			&p.AccountNumber,
			&p.Status,
			&p.CreatedAt,
			&p.Payload,
		); err != nil {
			http.Error(w, "scan failed", http.StatusInternalServerError)
			return
		}

		parents = append(parents, p)
	}

	writeJSON(w, http.StatusOK, parents)
}

func (a *App) createEvent(w http.ResponseWriter, r *http.Request) {
	var req EventRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	_, err := a.db.Exec(
		r.Context(),
		`
		INSERT INTO benchmark_event
		(id, parent_id, event_type, event_time, payload)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
		`,
		req.ID,
		req.ParentID,
		req.EventType,
		req.Payload,
	)

	if err != nil {
		http.Error(w, "insert failed", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"created": true,
		"id":      req.ID,
	})
}

func (a *App) parentRouter(w http.ResponseWriter, r *http.Request) {
	switch {
	case strings.HasSuffix(r.URL.Path, "/children"):
		a.children(w, r)

	case strings.HasSuffix(r.URL.Path, "/events"):
		a.events(w, r)

	case strings.HasSuffix(r.URL.Path, "/bundle"):
		a.bundle(w, r)

	default:
		a.parent(w, r)
	}
}

func main() {
	databaseURL := os.Getenv("DATABASE_URL")

	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		log.Fatal(err)
	}

	config.MaxConns = 50
	config.MinConns = 5
	config.MaxConnLifetime = 30 * time.Minute
	config.MaxConnIdleTime = 5 * time.Minute

	db, err := pgxpool.NewWithConfig(
		context.Background(),
		config,
	)

	if err != nil {
		log.Fatal(err)
	}

	defer db.Close()

	app := &App{
		db: db,
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/health", app.health)
	mux.HandleFunc("/parent/", app.parentRouter)
	mux.HandleFunc("/account/", app.accountParents)
	mux.HandleFunc("/event", app.createEvent)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Println("Go benchmark API listening on :8080")

	log.Fatal(server.ListenAndServe())
}
