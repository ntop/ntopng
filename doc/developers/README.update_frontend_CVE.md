# How to update a CVE on the frontend

If a new CVE arises for the frontend, the file to change is `package.json`. In this file there is the definition for all the frontend dependencies.

For example to update vite version, first find the package to update, then change the version. Below an example

```json
"vite": "^6.3.5", -> "vite": "^6.4.3",
```

Then, to verify that everything works, in `ntopng/`:

```bash
# remove installed dependencies
rm -rf node_modules/

# reinstall dependencies with new package version
npm install 

# build the dist for the frontend
npm run build
```

Then, after having reinstalled dependencies and rebuilt the dist, navigate to the ntopng UI, check that there are no errors in console that were not present before.

For example, if package X was to be updated, check that in all pages affecting package X, everything works as before.