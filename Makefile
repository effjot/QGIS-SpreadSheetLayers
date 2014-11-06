#/***************************************************************************
# SpreadsheetLayersPlugin
#
# Load layers from MS Excel and OpenOffice spreadsheets
#							 -------------------
#		begin				: 2014-10-30
#		git sha				: $Format:%H$
#		copyright			: (C) 2014 by Camptocamp
#		email				: info@camptocamp.com
# ***************************************************************************/
#
#/***************************************************************************
# *																		 *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or	 *
# *   (at your option) any later version.								   *
# *																		 *
# ***************************************************************************/

###################CONFIGURE HERE########################
PLUGINNAME = SpreadsheetLayers
PACKAGES_NO_UI = widgets
PACKAGES = $(PACKAGES_NO_UI) ui
TRANSLATIONS = SpreadsheetLayers_fr.ts

#this can be overiden by calling QGIS_PREFIX_PATH=/my/path make
# DEFAULT_QGIS_PREFIX_PATH=/usr/local/qgis-master
DEFAULT_QGIS_PREFIX_PATH=/usr
###################END CONFIGURE#########################

PACKAGESSOURCES := $(shell find $(PACKAGES) -name "*.py")
SOURCES := SpreadsheetLayersPlugin.py $(PACKAGESSOURCES)
SOURCES_FOR_I18N = $(SOURCES:%=../%)

# QGIS PATHS
ifndef QGIS_PREFIX_PATH
export QGIS_PREFIX_PATH=$(DEFAULT_QGIS_PREFIX_PATH)
endif

export LD_LIBRARY_PATH:="$(QGIS_PREFIX_PATH)/lib:$(LD_LIBRARY_PATH)"
export PYTHONPATH:=$(PYTHONPATH):$(QGIS_PREFIX_PATH)/share/qgis/python:$(HOME)/.qgis2/python/plugins:$(CURDIR)/..:$(CURDIR)/lib/python2.7/site-packages/
export PYTHONPATH:=$(PYTHONPATH):$(CURDIR)/test  # PG

ifndef QGIS_DEBUG
# Default to Quiet version
export QGIS_DEBUG=0
export QGIS_LOG_FILE=/dev/null
export QGIS_DEBUG_FILE=/dev/null
endif

default: compile
.PHONY: clean transclean deploy doc help

help:
	@echo
	@echo "------------------"
	@echo "Available commands"
	@echo "------------------"
	@echo
	@echo 'make [compile]'
	@echo 'make clean'
	@echo 'make test'
	@echo 'make package VERSION=\<version\> HASH=\<hash\>'
	@echo 'make deploy'
	@echo 'make stylecheck|pep8|pylint'
	@echo 'make help'

test: compile transcompile
	@echo
	@echo "----------------------"
	@echo "Regression Test Suite"
	@echo "----------------------"

	@# Preceding dash means that make will continue in case of errors
	@-export PYTHONPATH=`pwd`:$(PYTHONPATH); \
		export QGIS_DEBUG=0; \
		export QGIS_LOG_FILE=/dev/null; \
		nosetests -v --with-id --with-coverage --cover-package=. \
		3>&1 1>&2 2>&3 3>&- || true
	@echo "----------------------"
	@echo "If you get a 'no module named qgis.core error, try sourcing"
	@echo "the helper script we have provided first then run make test."
	@echo "e.g. source run-env-linux.sh <path to qgis install>; make test"
	@echo "----------------------"
	
################COMPILE#######################
compile:
	@echo
	@echo "------------------------------"
	@echo "Compile ui and resources forms"
	@echo "------------------------------"
	make -C ui
	make -C resources

################CLEAN#######################
clean:
	@echo
	@echo "------------------------------"
	@echo "Clean ui and resources forms"
	@echo "------------------------------"
	rm -f *.pyc
	make clean -C ui
	make clean -C resources

################TESTS#######################
.ONESHELL:
tests:
	@echo "------------------------------"
	@echo "Running test suite"
	@echo "------------------------------"
	export LD_LIBRARY_PATH=$(LD_LIBRARY_PATH)
	export PYTHONPATH=$(PYTHONPATH)
	./bin/pip install -q mock coverage
	unset GREP_OPTIONS
	nosetests -v test --nocapture --with-id --with-coverage --cover-package=$(PLUGINNAME) 3>&1 1>&2 2>&3 3>&- | \grep -v "^Object::" || true

################TRANSLATION#######################
updatei18nconf:
	echo "SOURCES = " $(SOURCES_FOR_I18N) > i18n/i18n.generatedconf
	echo "TRANSLATIONS = " $(TRANSLATIONS) >> i18n/i18n.generatedconf
	echo "CODECFORTR = UTF-8"  >> i18n/i18n.generatedconf
	echo "CODECFORSRC = UTF-8"  >> i18n/i18n.generatedconf

# transup: update .ts translation files
transup:updatei18nconf
	pylupdate4 -noobsolete i18n/i18n.generatedconf
	rm -f i18n/i18n.generatedconf

# transcompile: compile translation files into .qm binary format
transcompile: $(TRANSLATIONS:%.ts=i18n/%.qm)

# transclean: deletes all .qm files
transclean:
	rm -f i18n/*.qm

%.qm : %.ts
	lrelease $<

################PACKAGE############################
# Create a zip package of the plugin named $(PLUGINNAME).zip.
# This requires use of git (your plugin development directory must be a
# git repository).
# To use, pass a valid commit or tag as follows:
#   make package VERSION=0.3.2 HASH=release-0.3.2
#   make package VERSION=0.3.2 HASH=master
#   make package VERSION=0.3.2 HASH=83c34c7d

package: compile transcompile
	rm -f $(PLUGINNAME).zip
	rm -rf $(PLUGINNAME)/
	mkdir -p $(PLUGINNAME)/ui/
	cp ui/*.py $(PLUGINNAME)/ui/
	git archive -o $(PLUGINNAME).zip --prefix=$(PLUGINNAME)/ $(HASH)
	zip -d $(PLUGINNAME).zip $(PLUGINNAME)/\*Makefile
	zip -d $(PLUGINNAME).zip $(PLUGINNAME)/.gitignore
	zip -g $(PLUGINNAME).zip $(PLUGINNAME)/*/*
	rm -rf $(PLUGINNAME)/
	mv $(PLUGINNAME).zip $(PLUGINNAME).$(VERSION).zip
	echo "Created package: $(PLUGINNAME).$(VERSION).zip"

################DEPLOY####################
# Deploy to plugin repository
deploy: deploy/localhost

deploy/localhost:
	cp *.zip ../../geoform/dpfe/plugin/

deploy/dev:
	scp *.zip \
			pullymorges-dpfe-dev.gis.internal:/var/www/vhosts/pullymorges-dpfe/private/pullymorges_dpfe/geoform/dpfe/plugin/

################VALIDATION#######################
# validate syntax style
stylecheck: pep8 pylint

.ONESHELL:
pylint:
	@echo
	@echo "-----------------"
	@echo "Pylint violations"
	@echo "-----------------"
	@./bin/pip install -q pylint
	@export LD_LIBRARY_PATH=$(LD_LIBRARY_PATH)
	@export PYTHONPATH=$(PYTHONPATH)
	# @./bin/pylint --output-format=parseable --reports=y --rcfile=pylintrc $(PACKAGES_NO_UI) || true
	@./bin/pylint --reports=y --rcfile=pylintrc $(PACKAGES_NO_UI) || true

pep8:
	@echo
	@echo "-----------"
	@echo "PEP8 issues"
	@echo "-----------"
	@./bin/pip install -q pep8
	@./bin/pep8 --repeat --ignore=E501 --exclude ui,lib,doc resources . || true
