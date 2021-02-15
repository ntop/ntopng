build: package-lock.json Makefile
	npm run build

package-lock.json: package.json
	npm install

copy: build
	cp dist/ntop-widgets/*.js ../httpdocs/js/ntop-widgets
	echo "Please git add/commit ../httpdocs/js/ntop-widgets/*.js files"
