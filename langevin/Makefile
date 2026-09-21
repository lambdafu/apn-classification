SAGE = sage

.PHONY: reproduce check verify

reproduce:
	mkdir -p build
	$(SAGE) -python sage/reproduce.sage --output-dir build/run > build/run.log 2>&1

check:
	$(SAGE) -python sage/check_algorithms.sage

verify:
	$(SAGE) -python sage/verify.sage --records results --output build/verification.json
