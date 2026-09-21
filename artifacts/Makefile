SAGE = sage
WORKERS = 1
CUTOFF =

.PHONY: all reproduce reference planes refinement canonicity candidates5 reduce5 verify-reduction5 powers verify-powers historical-stabilizers verify-historical-stabilizers permutations5 permutations5-from-ea verify-permutations5 verify-permutations5-direct catalogue2019 verify-catalogue2019
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

powers:
	$(SAGE) -python sage/power_correspondences.sage --output build/power-correspondences.json

verify-powers:
	$(SAGE) -python sage/power_correspondences.sage --verify-record results/power-correspondences.json --output build/power-correspondences-verification.json

historical-stabilizers:
	$(SAGE) -python sage/historical_stabilizers.sage --output build/historical-stabilizers.json

verify-historical-stabilizers:
	$(SAGE) -python sage/verify_historical_stabilizers.sage --record results/historical-stabilizers.json --output build/historical-stabilizers-verification.json

permutations5:
	$(SAGE) -python sage/apn_permutations.sage --cutoff 16 --output build/apn-permutations-5.json

verify-permutations5:
	$(SAGE) -python sage/verify_extended_results.sage --record results/apn-permutations-from-ea-5.json --output build/apn-permutations-from-ea-5-verification.json

verify-permutations5-direct:
	$(SAGE) -python sage/verify_extended_results.sage --record results/apn-permutations-5-cutoff14.json --output build/apn-permutations-5-cutoff14-verification.json
	$(SAGE) -python sage/verify_extended_results.sage --record results/apn-permutations-5-cutoff16.json --output build/apn-permutations-5-cutoff16-verification.json

permutations5-from-ea:
	$(SAGE) -python sage/permutations_from_ea.sage --output build/apn-permutations-from-ea-5.json

catalogue2019:
	$(SAGE) -python sage/ea_ccz_catalogue.sage --output build/ea-ccz-catalogue-2019.json

verify-catalogue2019:
	$(SAGE) -python sage/verify_extended_results.sage --record results/ea-ccz-catalogue-2019.json --output build/ea-ccz-catalogue-2019-verification.json
	python3 sage/audit_historical_magma.py --output build/historical-magma-data-audit.json
