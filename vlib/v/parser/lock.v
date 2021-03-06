module parser

import v.ast
import v.table

fn (mut p Parser) lock_expr() ast.LockExpr {
	// TODO Handle aliasing sync
	p.register_auto_import('sync')
	pos := p.tok.position()
	is_rlock := p.tok.kind == .key_rlock
	p.next()
	mut lockeds := []ast.Ident{}
	for p.tok.kind == .name {
		lockeds << ast.Ident{
			language: table.Language.v
			// kind is set in checker once ident is processed
			// kind: .variable
			pos: p.tok.position()
			mod: p.mod
			name: p.tok.lit
			is_mut: true
			info: ast.IdentVar{}
		}
		p.next()
		if p.tok.kind == .lcbr {
			break
		}
		p.check(.comma)
	}
	stmts := p.parse_block()
	return ast.LockExpr{
		lockeds: lockeds
		stmts: stmts
		is_rlock: is_rlock
		pos: pos
	}
}
