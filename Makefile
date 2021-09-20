PROGS = sum-no-sync \
        sum-mutex \
        sum-spin-lock \
        sum-atomic-fxbox \
        sum-atomic-box 

SCMFILES = $(addsuffix .scm, $(PROGS))
CFILES = $(addsuffix .c, $(PROGS))

all: srfi/230.o $(PROGS)

$(PROGS): %: %.scm
	cyclone $<
	./$@

srfi/230.o: srfi/230.sld
	cyclone srfi/230.sld

test: all test.scm
	cyclone test.scm && ./test

clean: 
	rm -f $(PROGS) srfi/230.o srfi/230.c srfi/230.so *.meta *.o
