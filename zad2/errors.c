#include "errors.h"

// This function prints error if one occurs
int try_write(int number){
  if (number < 0){
    perror("write");
    exit(1);
  }
  return number;
}

// This function prints error if one occurs
int try_read(int number){
  if (number < 0){
    perror("read");
    exit(1);
  }
  return number;
}
