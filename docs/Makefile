DRAWIO := drawio
INKSCAPE := inkscape

SRC := $(wildcard *.drawio.svg)
OUT := $(patsubst %.drawio.svg,out/%.svg,$(SRC))

all: $(OUT)

out:
	mkdir -p out

out/%.svg: %.drawio.svg | out
	$(DRAWIO) --export --format pdf --crop --output out/$*.pdf $<
	$(INKSCAPE) out/$*.pdf --export-type=svg --export-text-to-path --export-filename=$@
	rm -f out/$*.pdf

clean:
	rm -rf out

.PHONY: all clean