PREFIX=/usr/local
BINDIR= $(PREFIX)/bin
LIBS = 
PROGRAM = tinyftp
CC=gcc
CFLAGS= 
COMPILE = $(CC) $(CFLAGS) -c
LINK = $(CC) $(CFLAGS)


all: $(PROGRAM)

$(PROGRAM):  main.o opts.o fileutils.o connections.o
	$(LINK) main.o opts.o fileutils.o connections.o -o $(PROGRAM)
main.o: main.c
	$(COMPILE) main.c
opts.o: opts.c
	$(COMPILE) opts.c
connections.o: connections.c
	$(COMPILE) connections.c
fileutils.o: fileutils.c
	$(COMPILE) fileutils.c
uninstall:
	cd $(BINDIR) && if [ -f "./$(PROGRAM)" ];then rm $(PROGRAM);fi
install:
	cp -f $(PROGRAM) $(BINDIR)
clean:
	rm -rf *.o $(PROGRAM)
	
