module main

import db.pg
import os
import strconv
import veb

const pool_size = 50

pub struct Context {
	veb.Context
}

pub struct App {
pub:
	pool chan &pg.DB
}

pub struct ParentResponse {
pub:
	id             i64
	account_number i64
	status         string
	created_at     string
	payload        string
}

fn row_value(row pg.Row, index int) string {
	if value := row.vals[index] {
		return value
	}
	return ''
}

fn parse_i64(value string) i64 {
	return strconv.parse_int(value, 10, 64) or { 0 }
}

fn acquire(pool chan &pg.DB) &pg.DB {
	return <-pool
}

fn release(pool chan &pg.DB, db &pg.DB) {
	pool <- db
}

@['/health']
pub fn (app &App) health(mut ctx Context) veb.Result {
	db := acquire(app.pool)
	defer {
		release(app.pool, db)
	}

	rows := db.exec('SELECT 1') or {
		return ctx.text('database unavailable')
	}

	if rows.len == 0 {
		return ctx.text('database unavailable')
	}

	return ctx.text('ok')
}

@['/parent/:id']
pub fn (app &App) parent(mut ctx Context, id string) veb.Result {
	db := acquire(app.pool)
	defer {
		release(app.pool, db)
	}

	rows := db.exec_param(
		'SELECT id, account_number, status, created_at, payload
		 FROM benchmark_parent
		 WHERE id = ($1)',
		id
	) or {
		return ctx.text('query failed')
	}

	if rows.len == 0 {
		return ctx.text('parent not found')
	}

	row := rows[0]

	return ctx.json(ParentResponse{
		id: parse_i64(row_value(row, 0))
		account_number: parse_i64(row_value(row, 1))
		status: row_value(row, 2)
		created_at: row_value(row, 3)
		payload: row_value(row, 4)
	})
}

fn main() {
	host := os.getenv('PGHOST')
	port := os.getenv('PGPORT').int()
	user := os.getenv('PGUSER')
	password := os.getenv('PGPASSWORD')
	database_name := os.getenv('PGDATABASE')

	pool := chan &pg.DB{
		cap: pool_size
	}

	for _ in 0 .. pool_size {
		mut database := pg.connect(pg.Config{
			host: host
			port: port
			user: user
			password: password
			dbname: database_name
		}) or {
			panic(err)
		}

		pool <- &database
	}

	app := &App{
		pool: pool
	}

	println('V benchmark API')
	println('PostgreSQL pool size: ${pool_size}')

	mut server_app := app

	veb.run_at[App, Context](
		mut server_app,
		family: .ip
		port: 8080
	) or {
		panic(err)
	}
}
