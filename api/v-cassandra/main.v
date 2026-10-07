module main

import os
import strconv
import veb


#flag -I/usr/local/include
#flag -L/usr/local/lib
#flag -lbenchmark_cassandra_bridge

#include "cassandra_bridge.h"


fn C.bc_init(&char) int
fn C.bc_health() int
fn C.bc_get_parent(i64) int

fn C.bc_parent_id() i64
fn C.bc_parent_account_number() i64

fn C.bc_parent_status() &char
fn C.bc_parent_created_at() &char
fn C.bc_parent_payload() &char


pub struct Context {
	veb.Context
}


pub struct App {}


pub struct HealthResponse {
pub:
	status string
}


pub struct ErrorResponse {
pub:
	error string
}


pub struct ParentResponse {
pub:
	id             i64
	account_number i64
	status         string
	created_at     string
	payload        string
}


fn c_string(
	value &char
) string {
	return unsafe {
		cstring_to_vstring(
			value
		)
	}
}


@['/health']
pub fn (
	app &App
) health(
	mut ctx Context
) veb.Result {
	if C.bc_health() != 0 {
		return ctx.json(
			HealthResponse{
				status:
					'database unavailable'
			}
		)
	}

	return ctx.json(
		HealthResponse{
			status: 'ok'
		}
	)
}


@['/parent/:id']
pub fn (
	app &App
) parent(
	mut ctx Context,
	id string
) veb.Result {
	parent_id :=
		strconv.parse_int(
			id,
			10,
			64
		) or {
			return ctx.json(
				ErrorResponse{
					error:
						'invalid parent id'
				}
			)
		}

	rc :=
		C.bc_get_parent(
			parent_id
		)

	if rc == 1 {
		return ctx.json(
			ErrorResponse{
				error:
					'parent not found'
			}
		)
	}

	if rc != 0 {
		return ctx.json(
			ErrorResponse{
				error:
					'query failed'
			}
		)
	}

	return ctx.json(
		ParentResponse{
			id:
				C.bc_parent_id()

			account_number:
				C.bc_parent_account_number()

			status:
				c_string(
					C.bc_parent_status()
				)

			created_at:
				c_string(
					C.bc_parent_created_at()
				)

			payload:
				c_string(
					C.bc_parent_payload()
				)
		}
	)
}


fn main() {
	host_env :=
		os.getenv(
			'CASSANDRA_HOST'
		)

	host :=
		if host_env == '' {
			'benchmark_cassandra'
		} else {
			host_env
		}

	if C.bc_init(
		host.str
	) != 0 {
		panic(
			'Unable to initialize Cassandra'
		)
	}

	app :=
		&App{}

	println(
		'V Cassandra benchmark API listening on :8080'
	)

	mut server_app :=
		app

	veb.run_at[App, Context](
		mut server_app,
		family: .ip
		port: 8080
	) or {
		panic(
			err
		)
	}
}
