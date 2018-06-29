#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <ctype.h>

#include "errors.h"

#define SOCK_PATH "./sock"
#define MAX_CLI 5
#define BUFF_SIZE 4096 //ideal 4096
#define TIMEOUT_SEC 60

#define DEBUG

//---------------------------------------------------------

// this function puts a 0 on the end of string
void fix_string(char *word){
  word[strlen(word)-1] = '\0';
}

// sends an information about functionality 
void help(int socket_num){

  char buff[BUFF_SIZE];
  
  sprintf(buff, "Zoznam prikazov:\n");
  strcat(buff, "- info: zobrazi cas, proc. cas a pamat\n");
  strcat(buff, "- help: zobrazi zoznam prikazov\n");
  strcat(buff, "- run 'name': spocita pocet riadkov, slov a znakov v 'name'\n");
  strcat(buff, "- quit: ukonci spojenie klienta so serverom\n");
  strcat(buff, "- halt: ukonci vsetky spojenia na serveri");
  
  try_write(write(socket_num, buff, strlen(buff)));
}

// sends date, time, processor time and memory usage
void info(int socket_num){
  char akt_cas[100];
  char proc_cas[100];
  char mem_use[100];
  char buff[BUFF_SIZE];
  int i,a;
  
  struct timeval cas;
  struct rusage usage;
  
  //gettimeofday(&cas, NULL);
  asm("movl $116, %%eax;"
      "push %0;"
      "push %%eax;"
		  "int $0x80;"
		  "pop %%eax;"
		  "pop %%eax;"
		  : 
      : "r"(&cas)
      : "%eax"
      );
  
  // specifying format of the message
  strftime(akt_cas, sizeof(akt_cas), "Datum: %d.%m.%Y Cas: %H:%M:%S", localtime((time_t *)&cas.tv_sec));
  
  // just to make sure that processor time will be visible
  for (i=0;i<10000000;i++)
  {
    a = a*a;
    a = a % 10;
  }
  
  //getrusage(RUSAGE_SELF, &usage);
  asm("movl $117, %%eax;"
      "push %0;"
      "push %1;"
      "push %%eax;"
		  "int $0x80;"
		  "pop %%eax;"
      "pop %%eax;"
		  "pop %%eax;"
		  : 
      : "r"(&usage), "r"(RUSAGE_SELF)
      : "%eax"
      );
      
  // specifying format of the messages    
  sprintf(proc_cas, "Proc. cas: %ld s, %ld us", usage.ru_utime.tv_sec, usage.ru_utime.tv_usec);
  sprintf(mem_use, "Pamat: %ldkb", usage.ru_maxrss);

  // connect the messages
  sprintf(buff,"%s %s %s", akt_cas, proc_cas, mem_use);
  
  // send information to socket
  try_write(write(socket_num, buff, strlen(buff)));
}

// recieve file and count lines, words, chars and send result to socket
void run(char *msg, int socket_num){

  int recieved, index, i, line_num = 1, word_num = 0, char_num = 0, word = 0;
  char buff[BUFF_SIZE], number[15];
  
  memset(buff, 0, BUFF_SIZE);
  
  // read while there is something to read on socket
  while((recieved = try_read(read(socket_num, buff, BUFF_SIZE))) > 0){
    
    #ifdef DEBUG
    printf("Prijimam buffer\n");
    #endif
    //printf("%s\n",buff);
    
    // iterate through the chars of read buffer
    for (i = 0; i < recieved; i++){
      if (!isspace(buff[i])){
        char_num++;
        word = 1; 
      }
      else{
        if (word){
          word_num++;
        }
        word = 0;
      }
      
      if (buff[i] == '\n'){
        line_num++;
      }
    }
    
    // if this read was the last
    if (recieved < BUFF_SIZE){
      break;
    }
    
    // clear buffer and read 'run '
    memset(buff, 0, BUFF_SIZE);
    try_read(read(socket_num, buff, 4));
  }
  
  // specify the message
  memset(buff, 0, BUFF_SIZE);
  memset(number, 0, BUFF_SIZE);
  strcat(buff, "Pocet riadkov: ");
  sprintf(number, "%d", line_num);
  strcat(buff, number);
  strcat(buff, ", pocet slov: ");
  sprintf(number, "%d", word_num);
  strcat(buff, number);
  strcat(buff, ", pocet znakov: ");
  sprintf(number, "%d", char_num);
  strcat(buff, number);
  
  #ifdef DEBUG
  printf("Odosielam spravu\n");
  #endif
  
  // send the message to socket
  try_write(write(socket_num, buff, strlen(buff)));
}

//---------------------------------------------------------

int server() {
  int index, line_num = 1, word_num = 0, char_num = 0, word = 0, cread;
	int s, i, j, ret_val, lis_socket, recieved, maxfd, cli_set[MAX_CLI];
	struct sockaddr_un ad, cli;
  struct timeval cas;
  
	char buff[BUFF_SIZE];
  char file_name[50], number[15];
  
  fd_set fdset;
  FILE *fp = NULL;
 
  // clear set for clients
  for (i=0;i<MAX_CLI;i++){
    cli_set[i] = 0;
  }
  
  #ifdef DEBUG
  printf("Zapinam server\n");
  #endif
  
	if ((lis_socket = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		// error while opening a socket
		perror("socket"); 
		exit(1);
	}
 
  #ifdef DEBUG
  printf("Socket vytvoreny uspesne (%d)\n", lis_socket);
  #endif

  // define address and socket type
	ad.sun_family = AF_UNIX;
	strcpy(ad.sun_path, SOCK_PATH);
	unlink(SOCK_PATH);
	
	if (bind(lis_socket, (struct sockaddr *) &ad, sizeof(ad)) == -1) {
		// error while binding the socket
		perror("bind");
		exit(1);
	}
 
  #ifdef DEBUG
  printf("Bind prebehol uspesne\n");
  #endif

	if (listen(lis_socket, 5) == -1) {
		// problem listening on socket
		perror("listen");
		exit(1);
	}
 
  #ifdef DEBUG
  printf("Listen prebehol uspesne\n");
  #endif
  
  // cycle for listening for incoming messages
  for (;;) {
  
    #ifdef DEBUG
    printf("\n");
    #endif
    
    // prepare variables and set up the set
    FD_ZERO(&fdset);
    FD_SET(0, &fdset);
    FD_SET(lis_socket, &fdset);
    cas.tv_sec = TIMEOUT_SEC;
    cas.tv_usec = 0;
    maxfd = lis_socket;
    memset(buff, 0, BUFF_SIZE);
    
    // add clients to the set and find max file desc.
    for (i = 0; i < MAX_CLI; i++){
      if (cli_set[i] > 0){
        FD_SET(cli_set[i], &fdset);
      }
      if (cli_set[i] > maxfd){
        maxfd = cli_set[i];
      }
    }
 
    #ifdef DEBUG
    printf("Stav klientov: ");
    for(i=0;i<MAX_CLI;i++){
      printf("%d ", cli_set[i]);
    }
    printf("\nSpustam select\n");
    #endif
    
    if ((ret_val = select(maxfd + 1, &fdset, NULL, NULL, &cas)) <= 0){
      
      if (ret_val == 0){
        printf("Nikto tu nie je.. koncim\n");
        exit(0);
      }
      // problem executing select
      perror("select");
      exit(1);
    }
    
    if (FD_ISSET(lis_socket, &fdset)){
      // new connection incomming
      if ((s = accept(lis_socket, NULL, NULL)) == -1) {
        // problem accepting message
        perror("accept");
        exit(1);
      }
      
      #ifdef DEBUG
      printf("Nove pripojenie (%d)\n", s);
      #endif
      
      // add new client to the set
      for (i = 0; i < MAX_CLI; i++){
        if (cli_set[i] == 0){
          cli_set[i] = s;
          break;
        }
      }
    }
    
    if (FD_ISSET(0, &fdset)){
      // something has been writen on the stdin
      recieved = try_read(read(0, buff, BUFF_SIZE));
      
      fix_string(buff);

      if (strcmp("help", buff) == 0) {  
        help(0);
      }
      else if(strcmp("info", buff) == 0){
        info(0);
      }
      else if (strncmp("run", buff, 3) == 0){
      
        line_num = 1;
        word_num = 0;
        char_num = 0;
        word = 0;
        
        // parse file name from argument
        strncpy(file_name, buff + 4, strlen(buff) - 4);
        
        // open the file only for reading
        fp = fopen(file_name, "r");
        
        if (fp == NULL){
          printf("Subor sa nepodarilo otvorit\n");
          continue;
        }
        
        #ifdef DEBUG
        printf("Subor uspesne otvoreny\n");
        #endif
        
        // SAME AS IN void run(int socket_num);
        while((cread = fread(buff, 1, BUFF_SIZE, fp)) > 0){
        
          #ifdef DEBUG
          printf("Citam zo suboru\n");
          #endif
                
          // count elements in buffer
          for (i = 0; i < cread; i++){
            if (!isspace(buff[i])){
              char_num++;
              word = 1;}
            else{
              if (word){
                word_num++;}
              word = 0;
            }
            if (buff[i] == '\n'){
              line_num++;}
            }  
          
          // last read was not full buffer -> end cycle
          if (cread < BUFF_SIZE){
            break;}
        }
        
        // finished reading from file
        #ifdef DEBUG
        printf("Dokoncil som citanie\n");
        #endif
        
        fclose(fp);
        
        // define the message
        memset(buff, 0, BUFF_SIZE);
        strcat(buff, "Pocet riadkov: ");
        sprintf(number, "%d", line_num);
        strcat(buff, number);
        strcat(buff, ", pocet slov: ");
        sprintf(number, "%d", word_num);
        strcat(buff, number);
        strcat(buff, ", pocet znakov: ");
        sprintf(number, "%d", char_num);
        strcat(buff, number);
        
        // printf the message
        try_write(write(0, buff, strlen(buff)));
      }
		  else if ((strcmp("quit", buff) == 0)||(strcmp("halt", buff) == 0)) {
              
        // finish all connections and end
        for (j = 0; j < MAX_CLI; j++){
          close(cli_set[j]);
        }
			  close(lis_socket);
			  return 0;
		  }
    }
    
    // iterate through clients in the set
    for (i = 0; i < MAX_CLI; i++){
      if ((cli_set[i] != 0)&&(FD_ISSET(cli_set[i], &fdset))){
        
        #ifdef DEBUG
        printf("Pokusam sa precitat (%d)\n", cli_set[i]);
        #endif
        
        // read message from the socket 
        recieved = try_read(read(cli_set[i], buff, 4));
 
        #ifdef DEBUG
        printf("Prijata sprava (z %d): %s\n", cli_set[i], buff);
        #endif 		
        
  		  if (strcmp("help", buff) == 0) {
          
          #ifdef DEBUG
          printf("Prijal som spravu help\n");
          #endif
          
          help(cli_set[i]);
  			  
  		  }
        else if (strcmp("info", buff) == 0) {
          
          #ifdef DEBUG
          printf("Prijal som spravu info\n");
          #endif
          
          info(cli_set[i]);
  		  }
        else if (strncmp("run", buff, 3) == 0){
          
          #ifdef DEBUG
          printf("Prijal som spravu run\n");
          #endif
          
          run(buff, cli_set[i]);
        }
  		  else if (strcmp("halt", buff) == 0) {
          
          #ifdef DEBUG
          printf("Prijal som spravu halt\n");
          #endif
          
          // finish all connections and end
          for (j = 0; j < MAX_CLI; j++){
            close(cli_set[j]);
          }
  			  close(lis_socket);
  			  return 0;
  		  }
        else if (strcmp("quit", buff) == 0) {
          
          #ifdef DEBUG
          printf("Prijal som spravu quit\n");
          #endif
          
          // disconnect only the sending client
          close(cli_set[i]);
          cli_set[i] = 0;
  		  }
      }
    }
  }
	return 0;
}

//-----------------------------------------------------------------

int client() {
	int ech_socket, recieved, cread;
	struct sockaddr_un ad;
	char buff[BUFF_SIZE];
  char file_name[50];
  
  FILE *fp = NULL;
  
  #ifdef DEBUG
  printf("Zapinam klienta\n");
  #endif

	if ((ech_socket = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		// error while opening a socket
		perror("socket");
		exit(1);
	}

  #ifdef DEBUG
  printf("Socket vytvoreny uspesne (%d)\n", ech_socket);
  #endif

  // set up the type of address
	memset(&ad, 0, sizeof(ad));
	ad.sun_family = AF_UNIX;
	strcpy(ad.sun_path, SOCK_PATH);
 
  
  #ifdef DEBUG
  printf("Chystam sa pripojit na server\n");
  #endif

	if (connect(ech_socket, (struct sockaddr *) &ad, sizeof(ad)) == -1) {
		// error while connecting to server
		perror("connect");
		exit(1);
	}
	
  #ifdef DEBUG
  printf("Som pripojeny na server\n");
  #endif

  // cycle for sending commands to server
	for (;;) {
 
    #ifdef DEBUG
    printf("\n");
    #endif
    
    // read command to the buffer
		while((cread = strlen(fgets(buff, BUFF_SIZE, stdin))) < 3){
      // make sure im not reading empty line
    }
    
    fix_string(buff);
    
    if ((strcmp("help", buff) == 0)||(strcmp("info", buff) == 0)){
      try_write(write(ech_socket, buff, 4));
    }
    else if (strncmp("run", buff, 3) == 0){
    
      if(strlen(buff) < 5){
        printf("Tento prikaz potrebuje mat subor v argumente\n");
        continue;
      }
    
      // parse file name from argument
      memset(file_name, 0, 50);
      strncpy(file_name, buff + 4, strlen(buff) - 4);
      
      // open the file only for reading
      fp = fopen(file_name, "r");
      
      if (fp == NULL){
        printf("Subor sa nepodarilo otvorit %s\n", file_name);
        continue;
      }
      
      #ifdef DEBUG
      printf("Subor uspesne otvoreny %s\n", file_name);
      #endif
      
      // read from file until the end
      while((cread = fread(buff, 1, BUFF_SIZE, fp)) > 0 ){
        
        #ifdef DEBUG
        printf("Posielam buffer\n");
        #endif
        
        if (cread < BUFF_SIZE){
        // when the file is shorter than BUFF_SIZE or im finished
          try_write(write(ech_socket, "runs", 4));
          try_write(write(ech_socket, buff, strlen(buff)));
        }
        else{
        // if read the whole thing and need to read again
          try_write(write(ech_socket, "run ", 4));
          try_write(write(ech_socket, buff, BUFF_SIZE));
        }
        memset(buff, 0, BUFF_SIZE);
      }
      
      #ifdef DEBUG
      printf("Subor odoslany\n");
      #endif
      
      fclose(fp);
      fp = NULL;
    }
    else if ((strcmp("quit", buff) == 0)||(strcmp("halt", buff) == 0)) {
    
      try_write(write(ech_socket, buff, 4));
      
      #ifdef DEBUG
      printf("Zatvaram socket\n");
      #endif
      
			close(ech_socket);
			exit(0);
		}
     
    // recieve message from server and print
    memset(buff, 0, BUFF_SIZE);
    recieved = try_read(read(ech_socket, buff, BUFF_SIZE));

    #ifdef DEBUG
    printf("Prijal som spravu s dlzkou %d\n", recieved);
    #endif
    
		printf("%s\n", buff);
    memset(buff, 0, BUFF_SIZE);
	}

	return 0;
}

//-----------------------------------------------------------------

int main(int argc, char *argv[])
{
	if ((argc == 1)||(strcmp(argv[1], "-s") == 0)) {
		// zapni server
		server();
	}
	else if (strcmp(argv[1], "-c") == 0) {
		// zapni klienta
		client();
	}
	else {
		printf("Neznamy argument...(skus -s, -c)\n");
	}
	return 0;
}


