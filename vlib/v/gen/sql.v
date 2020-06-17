// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module gen

import v.ast
import strings

// pg,mysql etc
const (
	dbtype = 'sqlite'
)

fn (mut g Gen) sql_expr(node ast.SqlExpr) {
	g.sql_i = 0
	/*
	`nr_users := sql db { ... }` =>
	```
	sql_init_stmt()
	sql_bind_int()
	sql_bind_string()
	...
	int nr_users = get_int(stmt)
	```
	*/
	cur_line := g.go_before_stmt(0)
	mut q := 'select '
	if node.is_count {
		// select count(*) from User
		q += 'count(*) from $node.table_name'
	}
	if node.has_where {
		q += ' where '
	}
	// g.write('${dbtype}__DB_q_int(*(${dbtype}__DB*)${node.db_var_name}.data, tos_lit("$q')
	g.sql_stmt_name = g.new_tmp_var()
	db_name := g.new_tmp_var()
	g.writeln('\n\t// sql')
	// g.write('${dbtype}__DB $db_name = *(${dbtype}__DB*)${node.db_var_name}.data;')
	g.write('${dbtype}__DB $db_name = ${node.db_var_name};')
	// g.write('sqlite3_stmt* $g.sql_stmt_name = ${dbtype}__DB_init_stmt(*(${dbtype}__DB*)${node.db_var_name}.data, tos_lit("$q')
	g.write('sqlite3_stmt* $g.sql_stmt_name = ${dbtype}__DB_init_stmt($db_name, tos_lit("$q')
	if node.has_where && node.where_expr is ast.InfixExpr {
		g.expr_to_sql(node.where_expr)
	}
	g.writeln('"));')
	// Dump all sql parameters generated by our custom expr handler
	binds := g.sql_buf.str()
	g.sql_buf = strings.new_builder(100)
	g.writeln(binds)
	g.writeln('puts(sqlite3_errmsg(${db_name}.conn));')
	g.writeln('$cur_line ${dbtype}__get_int_from_stmt($g.sql_stmt_name);')
}

fn (mut g Gen) expr_to_sql(expr ast.Expr) {
	// Custom handling for infix exprs (since we need e.g. `and` instead of `&&` in SQL queries),
	// strings. Everything else (like numbers, a.b) is handled by g.expr()
	//
	// TODO `where id = some_column + 1` needs literal generation of `some_column` as a string,
	// not a V variable. Need to distinguish column names from V variables.
	match expr {
		ast.InfixExpr {
			g.expr_to_sql(it.left)
			match it.op {
				.eq { g.write(' = ') }
				.and { g.write(' and ') }
				else {}
			}
			g.expr_to_sql(it.right)
		}
		ast.StringLiteral {
			// g.write("'$it.val'")
			g.inc_sql_i()
			g.sql_buf.writeln('sqlite3_bind_text($g.sql_stmt_name, $g.sql_i, "$it.val", $it.val.len, 0);')
		}
		ast.IntegerLiteral {
			g.inc_sql_i()
			g.sql_buf.writeln('sqlite3_bind_int($g.sql_stmt_name, $g.sql_i, $it.val);')
		}
		else {
			g.expr(expr)
		}
	}
	/*
	ast.Ident {
			g.write('$it.name')
		}
		else {}
	*/
}

fn (mut g Gen) inc_sql_i() {
	g.sql_i++
	g.write('?$g.sql_i')
}