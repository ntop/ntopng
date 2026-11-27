# make dist  -> build the site into dist/ (same URLs as the Sphinx docs: /guides/ntopng/<page>.html)
# make serve -> build dist/ if needed and serve it at http://localhost:$(PORT)/guides/ntopng/
PORT ?= 4173
.PHONY: dist serve clean

node_modules: package.json
	npm install
	@touch node_modules

dist: node_modules
	npm run build

serve: dist
	npx vitepress preview . --host 0.0.0.0 --port $(PORT)

clean:
	rm -rf dist .vitepress/cache
