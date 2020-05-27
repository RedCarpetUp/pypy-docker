```python
# You should use this in your python code

if implementation.name == "pypy":
    from psycopg2cffi import compat

    compat.register()


if version_info < (3, 6, 0):
    raise RuntimeError(
        "Not intended to run on the Python less than '3.6.0' Got version: '%s.%s.%s'"
        % version_info[:3]
    )

if version_info < (3, 7, 0):
    try:
        import async_generator

    # from async_exit_stack import AsyncExitStack
    # from async_generator import asynccontextmanager
    except ImportError:
        raise ImportError(
            "You should install 'async_generator' package to run tests in Python 3.6"
        )
    else:
        from contextlib import asynccontextmanager
```

1. Build using  `docker build  . -t mypypy`
2. I run fastapi code using `docker run --network="host" -it -e ENV=local -v $(pwd):/work/ mypypy gunicorn --chdir /work --worker-tmp-dir=/dev/shm -k uvicorn.workers.UvicornH11Worker --preload   --workers=10 --log-level=debug  --access-logfile=- --error-logfile=- --disable-redirect-access-to-syslog --timeout=10 --graceful-timeout=100 --keep-alive=300 rc.main:app -b 0.0.0.0:8000`

What doesnt work:
1. The `opencv` build is still iffy


