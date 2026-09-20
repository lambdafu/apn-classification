SAGE = sage
WORKERS = 1
CUTOFF =

.PHONY: all reproduce reference planes refinement canonicity candidates5 reduce5 verify-reduction5
all: reproduce

reproduce:
	$(SAGE) sage/apn_counts.sage --cython --output build/apn-counts.json

reference:
	$(SAGE) sage/apn_counts.sage --output build/apn-counts-reference.json

planes:
	$(SAGE) sage/affine_planes.sage --output build/affine-planes.json

refinement:
	$(SAGE) sage/affine_refinement.sage --output build/affine-refinement.json

canonicity:
	$(SAGE) sage/affine_canonicity.sage --output build/affine-canonicity.json

candidates5:
	$(SAGE) sage/ea_candidates.sage --dimension 5 $(if $(CUTOFF),--cutoff $(CUTOFF)) --output build/ea-candidates-5.json

reduce5:
	$(SAGE) -python sage/ea_reduce.sage --workers $(WORKERS) --output build/ea-reduction-5.json

verify-reduction5:
	$(SAGE) -python sage/verify_ea_reduction.sage --record results/ea-reduction-5.json --output build/ea-reduction-5-verification.json
