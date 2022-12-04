build:
	rm -rf ntopng_package
	mkdir -p ntopng_package/ntopng
	cp __init__.py ntopng_package/ntopng
	cp flow.py host.py interface.py ntopng.py ntopng_package/ntopng
	cp setup.py ntopng_package


install:
	cd ntopng_package; pip install .
