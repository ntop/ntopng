#
# https://packaging.python.org/en/latest/tutorials/packaging-projects/
#


install:
	pip3 install .

clean:
	/bin/rm -rf __pycache__ ntopng.egg-info build/ dist


build: clean
	# python3 -m pip install --upgrade build
	# python3 -m pip install --upgrade twine
	python3 -m build


upload_test: build
	# Test site
	python3 -m twine upload --repository testpypi dist/*

	# Install package
	# python3 -m pip install --index-url https://test.pypi.org/simple/ --no-deps ntopng


upload: build
	# Official PyPy
	python3 -m twine upload dist/*
	pip3 install ntopng
