############################################
# Preamble
############################################

CATALA_OPTS?=
CLERK_OPTS?=--makeflags="$(MAKEFLAGS)"

CLERK=_build/default/build_system/clerk.exe --exe "_build/default/compiler/catala.exe" \
	$(CLERK_OPTS) $(if $(CATALA_OPTS),--catala-opts=$(CATALA_OPTS),) test

# Forces all the tests to be redone
.FORCE:

%.catala_en %.catala_fr %.catala_pl: .FORCE
    # Here we cd to the root of the Catala repository such that the paths \
	# displayed in error messages start with `tests/` uniformly.
	@cd ..; $(CLERK) tests/$@
