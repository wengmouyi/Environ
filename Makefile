#!/bin/bash
#
# Copyright (C) 2018 ENVIRON (www.quantum-environment.org)
#
#    This file is part of Environ version 1.1
#
#    Environ 1.1 is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    Environ 1.1 is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more detail, either the file
#    `License' in the root directory of the present distribution, or
#    online at <http://www.gnu.org/licenses/>.
#
# Author: Oliviero Andreussi (Department of Physics, University of North Texas)
#	      Edan Bainglass (Department of Physics, University of North Texas)
#

ifndef VERBOSE
.SILENT:
endif

ENVIRON_VERSION=1.1

default: all

all: doc libenviron

doc:
	if test -d Doc ; then (cd Doc; $(MAKE) || exit 1 ); fi

################################################################################
# COMPILATION ROUTINES
################################################################################

# for development purposes
recompile: compile-environ compile-qe-pw

compile-environ: check-environ-makeinc libsdir
	@ $(MAKE) libfft
	@ $(MAKE) libutil
	@ $(MAKE) libenv

decompile-environ: 
	@ printf "\nCleaning up Environ...\n\n"; $(MAKE) clean

compile-qe-pw: check-qe-makeinc
	@ printf "\nCompiling QE...\n\n"
	@ (cd ../ && $(MAKE) pw)

decompile-qe-pw:
	@ printf "\nCleaning up QE...\n\n"
	@ (cd ../ && $(MAKE) clean)

libfft:
	@ printf "\nCompiling FFTXlib...\n\n"
	@ ( \
		cd FFTXlib && $(MAKE) TLDEPS=all || exit 1; \
		mv *.a ../libs \
	 )

libutil: 
	@ printf "\nCompiling UtilXlib...\n\n"
	@ ( \
		cd UtilXlib && $(MAKE) TLDEPS=all || exit 1; \
		mv *.a ../libs \
	)

libenv:
	@ printf "\nCompiling Environ/src...\n\n"
	@ ( \
		cd src && $(MAKE) TLDEPS=all || exit 1; \
	   	mv *.a ../libs \
	)

libsdir:
	@ test -d libs || mkdir libs

check-environ-makeinc:
	@ if [ ! -e make.inc ]; then \
		  printf "\nMissing make.inc. Please configure installation.\n\n"; \
		  exit 1; \
	  fi
	
check-qe-makeinc:
	@ if [ ! -e ../make.inc ]; then \
		  printf "\nMissing QE/make.inc. Please configure the QE installation.\n\n"; \
		  exit 1; \
	  fi

################################################################################
# PATCHING ROUTINES FOR QE+ENVIRON
################################################################################

patch-qe: check-qe-makeinc
	@ printf "\nApplying QE patches using Environ version ${ENVIRON_VERSION}...\n"
	@ ./patches/environpatch.sh -patch

revert-qe-patches: check-qe-makeinc
	@ printf "\nReverting QE patches using Environ version ${ENVIRON_VERSION}...\n"
	@ ./patches/environpatch.sh -revert

update-QE-dependencies:
	@ printf "\nUpdating QE dependencies...\n\n"
	@ (cd ../ && ./install/makedeps.sh)

################################################################################
# INSTALL ROUTINES FOR QE+ENVIRON
################################################################################

install-QE+Environ: check-environ-makeinc check-qe-makeinc
	@ printf "\nThis will compile Environ, patch QE, then compile QE.\n"
	@ printf "\nDo you wish to proceed (y|n)? "; read c; \
	if [ "$$c" = "y" ]; then \
		printf "\nUse # cores (default = 1) -> "; read cores; \
		$(MAKE) -j$${cores:=1} compile-environ; \
		$(MAKE) -j$${cores:=1} patch-qe; \
		$(MAKE) -j$${cores:=1} update-QE-dependencies; \
		$(MAKE) -j$${cores:=1} compile-qe-pw; \
	else \
		echo; \
	fi 2>&1 | tee install/compilation.log; \
	$(MAKE) check-for-errors

check-for-errors:
	@ if grep -qE "error #[0-9]+" install/compilation.log; then \
		printf "\nErrors found. See install/compilation.log\n\n"; \
	else \
		printf "\nInstallation successful!\n\n"; \
	fi

uninstall-QE+Environ: 
	@ printf "\nThis will decompile Environ, revert QE patches, and decompile QE.\n"
	@ printf "\nDo you wish to proceed (y|n)? "; read c; \
	if [ "$$c" = "y" ]; then \
		$(MAKE) decompile-environ; \
		$(MAKE) revert-qe-patches; \
		$(MAKE) update-QE-dependencies; \
		$(MAKE) decompile-qe-pw; \
		printf "\nDone!\n\n"; \
	else \
		echo; \
	fi

################################################################################
# CLEANING
################################################################################

clean: check-environ-makeinc
	@ $(MAKE) clean-src
	@ $(MAKE) clean-libs
	@ $(MAKE) clean-fft
	@ $(MAKE) clean-util

clean-src:
	@ printf "src..........."
	@ (cd src && $(MAKE) clean)
	@ printf " done!\n"

clean-fft:
	@ printf "FFTXlib......."
	@ (cd FFTXlib && $(MAKE) clean)
	@ printf " done!\n"

clean-util:
	@ printf "UtilXlib......"
	@ (cd UtilXlib && $(MAKE) clean)
	@ printf " done!\n"

clean-libs:
	@ printf "libs.........."
	@ if test -d libs; then rm -fr libs; fi
	@ printf " done!\n"

clean-doc:
	@ printf "Docs.........."
	@ (cd Doc && $(MAKE) clean)
	@ printf " done!\n"

# remove files produced by "configure" as well
veryclean: clean
	@ printf "Config........"
	@ (cd install && \
	   rm -rf *.log configure.msg config.status)
	@ rm make.inc
	@ printf " done!\n"

distclean: clean 
	@ $(MAKE) clean-doc