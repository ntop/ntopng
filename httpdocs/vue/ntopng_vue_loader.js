/**
    (C) 2022 - ntop.org    
*/

const ntopng_vue_loader = function() {
    const { loadModule } = window['vue3-sfc-loader'];

    const loadOptions = {
	moduleCache: {
	    vue: Vue,
	},
	
	getFile(url) {
            return fetch(url).then((response) => {
                if (response.ok) { return response.text(); }
                else {
                    console.error("ntopng_vue_loader fail loading: ${url}");
                    return Promise.reject(response);
                }
            }).catch((err) => {
                console.error("ntopng_vue_loader fail loading: ${url}");
                throw err;
            });
	},
	
	addStyle(styleStr) {
            const style = document.createElement('style');
            style.textContent = styleStr;
            const ref = document.head.getElementsByTagName('style')[0] || null;
            document.head.insertBefore(style, ref);
	},
    };
    return {
	loadModule,
	loadOptions,
    };
}();
