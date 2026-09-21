"""Build only this project's optional Cython kernel through Sage."""
import hashlib
from pathlib import Path


def load_kernel():
    from sage.misc.cython import cython_import
    path = Path(__file__).resolve().parents[1] / 'cython/extensions.pyx'
    module = cython_import(str(path), use_cache=True, annotate=False, sage_namespace=False)
    return module, dict(source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                        binary_sha256=hashlib.sha256(Path(module.__file__).read_bytes()).hexdigest())
