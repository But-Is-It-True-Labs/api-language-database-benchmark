package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	gocql "github.com/apache/cassandra-gocql-driver/v2"
)

type App struct {
	db *gocql.Session
}

type Parent struct {
	ID            int64     `json:"id"`
	AccountNumber int64     `json:"account_number"`
	Status        string    `json:"status"`
	CreatedAt     time.Time `json:"created_at"`
	Payload       string    `json:"payload"`
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
	var releaseVersion string

	err := a.db.Query(
		"SELECT release_version FROM system.local WHERE key = 'local'",
	).
		Consistency(gocql.One).
		ScanContext(r.Context(), &releaseVersion)

	if err != nil {
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

	err = a.db.Query(
		`
		SELECT id, account_number, status, created_at, payload
		FROM parent_by_id
		WHERE id = ?
		`,
		id,
	).
		Consistency(gocql.One).
		ScanContext(
			r.Context(),
			&p.ID,
			&p.AccountNumber,
			&p.Status,
			&p.CreatedAt,
			&p.Payload,
		)

	if err != nil {
		if errors.Is(err, gocql.ErrNotFound) {
			http.Error(w, "parent not found", http.StatusNotFound)
			return
		}

		log.Printf("parent query error: %v", err)
		http.Error(w, "query failed", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, p)
}

func main() {
	host := os.Getenv("CASSANDRA_HOST")
	if host == "" {
		host = "benchmark_cassandra"
	}

	cluster := gocql.NewCluster(host)
	cluster.Keyspace = "benchmark"
	cluster.Consistency = gocql.One
	cluster.Timeout = 10 * time.Second
	cluster.ConnectTimeout = 10 * time.Second

	db, err := cluster.CreateSession()
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	app := &App{
		db: db,
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/health", app.health)
	mux.HandleFunc("/parent/", app.parent)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Println("Go Cassandra benchmark API listening on :8080")

	log.Fatal(server.ListenAndServe())
}
