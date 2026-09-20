"""Load optional Cython kernels through Sage and record build provenance."""
import hashlib
import sysconfig
from pathlib import Path


def load_kernel(name):
    import Cython
    from sage.misc.cython import cython_import
    root = Path(__file__).resolve().parents[1]
    source = root / 'cython' / (name + '.pyx')
    module = cython_import(str(source), use_cache=True, annotate=False,
                           sage_namespace=False)
    binary = Path(module.__file__)
    metadata = {
        'loader': 'sage.misc.cython.cython_import',
        'cython_version': Cython.__version__,
        'source': str(source.relative_to(root)),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'extension_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
        'python_build_configuration': {
            key: sysconfig.get_config_var(key)
            for key in ('CC', 'CFLAGS', 'LDSHARED')},
        'note': 'Compiler defaults are Python build configuration, not a captured compiler invocation; source directives also apply.',
    }
    return module, metadata
