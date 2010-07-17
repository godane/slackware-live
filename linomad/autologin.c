#include <unistd.h>

int main(int argc, char *argv[]) {
	//~ execlp( "login", "login", "-f", "root", 0);
	execlp( "login", "login", "-f", "linomad", 0);
}
