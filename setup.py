import pathlib

from setuptools import Extension, setup, find_packages
from Cython.Build import cythonize

libuv_ext = Extension(
    name="moovparser.moovparser",
    sources=["src/moovparser/moovparser.pyx"],
)

print(find_packages("src"))
setup(
    name="mp4bwp",
    version="1.0.0",
    packages=find_packages("src"),
    package_dir={"": "src"},
    ext_modules=cythonize(
        [libuv_ext],
        annotate=True, language_level='3'
    ),
)
