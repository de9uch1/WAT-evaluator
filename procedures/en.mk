#!/usr/bin/env gmake -f
# Copyright (c) Hiroyuki Deguchi
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

MOSES_SCRIPTS := mosesdecoder-2.1.1/scripts
MOSES_TOKENIZER := $(MOSES_SCRIPTS)/tokenizer/tokenizer.perl
Z2H_SCRIPT := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))/z2h.pl

# for evaluation
MOSES_BLEU := $(MOSES_SCRIPTS)/generic/multi-bleu.perl
RIBES_DIR := RIBES-1.02.4
RIBES_SCRIPT := $(RIBES_DIR)/RIBES.py

ifndef REF
	$(error REF not set.)
endif
REF_FILE := $(dir $(REF))/../$(notdir $(REF))

ifndef SYSOUT
	$(error SYSOUT not set.)
endif
SYSOUT_FILE := $(SYSOUT).hypo

ifndef METRIC
	$(error Set METRIC to 'bleu' or 'ribes'.)
endif

$(MOSES_TOKENIZER) $(MOSES_BLEU):
	@echo "Cloning Moses github repository (for tokenization and evaluation)..."
	git clone "https://github.com/moses-smt/mosesdecoder.git" -b RELEASE-2.1.1 mosesdecoder-2.1.1

$(RIBES_SCRIPT):
	@echo "Downloading RIBES script (for evaluation)..."
	curl -sL "http://www.kecl.ntt.co.jp/icl/lirg/ribes/package/RIBES-1.02.4.tar.gz" | tar xz

define tokenize
	cat $1 \
		| perl -C $(Z2H_SCRIPT) \
		| perl -C $(MOSES_TOKENIZER) -l en -threads 8 \
		> $2
endef

$(REF_FILE): $(REF) $(MOSES_TOKENIZER)
	$(call tokenize,$<,$@) 

$(SYSOUT_FILE): $(SYSOUT) $(MOSES_TOKENIZER)
	$(call tokenize,$<,$@)

.PHONY: eval_bleu
eval_bleu: $(REF_FILE) $(SYSOUT_FILE) $(MOSES_BLEU)
	perl -C $(MOSES_BLEU) $(REF_FILE) < $(SYSOUT_FILE) 2>/dev/null

.PHONY: eval_ribes
eval_ribes: $(REF_FILE) $(SYSOUT_FILE) $(RIBES_SCRIPTS)
	python3 $(RIBES_SCRIPT) -c -r $(REF_FILE) $(SYSOUT_FILE) 2>/dev/null

.PHONY: evaluate
evaluate: eval_$(METRIC)

.DEFAULT: evaluate
