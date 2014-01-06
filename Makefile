CC = clang

CFLAGS = -O2 -Wall -Werror
FRAMEWORKS := -framework Foundation -framework IOKit -framework Security
LDFLAGS = $(FRAMEWORKS) -arch x86_64 -dynamic

EXE := security-advisor


all:
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(EXE) main.m

clean:
	rm -f $(EXE)
