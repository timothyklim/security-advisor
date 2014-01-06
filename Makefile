CC = clang

CFLAGS = -O2 -Wall -Werror
FRAMEWORKS := -framework Foundation -framework IOKit -framework Security
LIBRARIES := -lobjc
LDFLAGS = $(LIBRARIES) $(FRAMEWORKS) -arch x86_64 -dynamic


all:
	$(CC) $(CFLAGS) $(LDFLAGS) -o security-advisor main.m

clean:
	rm -f *.o security-advisor
