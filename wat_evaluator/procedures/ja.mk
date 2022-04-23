#!/usr/bin/env gmake -f
# Copyright (c) Hiroyuki Deguchi
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

MOSES_SCRIPTS := mosesdecoder-2.1.1/scripts
KYTEA_ROOT := kytea-0.4.6
KYTEA_TOKENIZER := $(KYTEA_ROOT)/bin/kytea
KYTEA_MODEL := $(KYTEA_ROOT)/jp-0.4.2-utf8-1.mod
WAT_SCRIPTS := WAT-scripts
SEG_SCRIPTS := script.segmentation.distribution

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
	@echo 'Cloning Moses github repository (for tokenization and evaluation)...'
	git clone "https://github.com/moses-smt/mosesdecoder.git" -b RELEASE-2.1.1 mosesdecoder-2.1.1

$(KYTEA_TOKENIZER):
	@echo 'Downloading Kytea source code (for tokenization)...'
	curl -sL "http://www.phontron.com/kytea/download/kytea-0.4.6.tar.gz" | tar xz
	cd $(KYTEA_ROOT) && ./configure --prefix=$(pwd) >&2
	make -C $(KYTEA_ROOT) -j4 clean >&2
	make -C $(KYTEA_ROOT) -j4 >&2
	make -C $(KYTEA_ROOT) -j4 install >&2

$(KYTEA_MODEL): $(KYTEA_TOKENIZER)
	cd $(@D) && curl -O "http://www.phontron.com/kytea/download/model/$(@F).gz" >&2
	cd $(@D) && gzip -d $(@F).gz >&2

$(WAT_SCRIPTS):
	@echo 'Cloning WAT-scripts github repository (for preprocess)...'
	git clone "https://github.com/hassyGO/WAT-scripts.git" >&2

$(RIBES_SCRIPT):
	@echo 'Downloading RIBES script p(for evaluation)...'
	curl -sL "http://www.kecl.ntt.co.jp/icl/lirg/ribes/package/RIBES-1.02.4.tar.gz" | tar xz

define tokenize
	cat $1 \
		| perl -C -pe 'use utf8; s/(.)［[０-９．]+］$$/$${1}/;' \
		| sh $(WAT_SCRIPTS)/remove-space.sh \
		| perl -C $(WAT_SCRIPTS)/h2z-utf8-without-space.pl \
		| $(KYTEA_TOKENIZER) -model $(KYTEA_MODEL) -out tok \
		| perl -C -pe 's/^ +//; s/ +$$//; s/ +/ /g;' \
		| perl -C -pe 'use utf8; while(s/([０-９]) ([０-９])/$$1$$2/g){} s/([０-９]) (．) ([０-９])/$$1$$2$$3/g; while(s/([Ａ-Ｚ]) ([Ａ-Ｚａ-ｚ])/$$1$$2/g){} while(s/([ａ-ｚ]) ([ａ-ｚ])/$$1$$2/g){}' \
		> $2
endef

$(REF_FILE): $(REF) $(KYTEA_TOKENIZER) $(KYTEA_MODEL) $(WAT_SCRIPTS)
	$(call tokenize,$<,$@)

$(SYSOUT_FILE): $(SYSOUT) $(KYTEA_TOKENIZER) $(KYTEA_MODEL) $(WAT_SCRIPTS)
	$(call tokenize,$<,$@)

.PHONY: eval_bleu
eval_bleu: $(REF_FILE) $(SYSOUT_FILE) $(MOSES_BLEU)
	perl -C $(MOSES_BLEU) $(REF_FILE) < $(SYSOUT_FILE) 2>/dev/null

.PHONY: eval_ribes
eval_ribes: $(REF_FILE) $(SYSOUT_FILE) $(RIBES_SCRIPT)
	python3 $(RIBES_SCRIPT) -c -r $(REF_FILE) $(SYSOUT_FILE) 2>/dev/null

.PHONY: evaluate
evaluate: eval_$(METRIC)

.DEFAULT: evaluate
