module main

import db.mysql
import os
import strconv
import veb

const pool_size = 50

pub struct Context {
	veb.Context
}

pub struct App {
pub:
	pool chan &mysql.DB
}

pub struct ParentResponse {
pub:
	id             i64
	account_number i64
	status         string
	created_at     string
	payload        string
}

fn row_value(row mysql.Row, index int) string {
	if index >= 0 && index < row.vals.len {
		return row.vals[index]
	}
	return ''
}

fn parse_i64(value string) i64 {
	return strconv.parse_int(value, 10, 64) or { 0 }
}

fn acquire(pool chan &mysql.DB) &mysql.DB {
	return <-pool
}

fn release(pool chan &mysql.DB, db &mysql.DB) {
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
		 WHERE id = ?',
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
	host := os.getenv('MYSQLHOST')
	port := os.getenv('MYSQLPORT').int()
	user := os.getenv('MYSQLUSER')
	password := os.getenv('MYSQLPASSWORD')
	database_name := os.getenv('MYSQLDATABASE')

	pool := chan &mysql.DB{
		cap: pool_size
	}

	for _ in 0 .. pool_size {
		mut database := mysql.connect(mysql.Config{
			host: host
			port: port
			username: user
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
	println('MariaDB pool size: ${pool_size}')

	mut server_app := app

	veb.run_at[App, Context](
		mut server_app,
		family: .ip
		port: 8080
	) or {
		panic(err)
	}
}
