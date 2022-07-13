/***************************************************************************
 *            fileutils.c
 *
 *  Copyright 2005 Dimitur Kirov
 *  dkirov@gmail.com
 ****************************************************************************/

/*
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
 
#include <stdio.h>
#include <unistd.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <arpa/inet.h> 
#include <string.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <signal.h>
#include <assert.h>
#include <netdb.h>
#include <errno.h>
#include <dirent.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>
#include <fcntl.h>
#include "defines.h"
#include "cmdparser.h"
#include "fileutils.h"

/**
 * Check if directory exists. If it exists return an open descriptor to that directory.
 * If it is not a directory, or does not exists return NULL.
 */
static DIR * ensure_dir_exists(int sock,const char*path) {
	DIR *dir =opendir(path) ;
	if(dir==NULL) {
		printf("Error openning directory \"%s\", error was:\n  ",path);
		send_repl(sock,REPL_550);
		switch(errno) {
			case EACCES:
				printf("Access denied.\n");
				closedir(dir);
				return NULL;
			case EMFILE:
				printf("Too many file descriptors in use by process.\n");
				closedir(dir);
				return NULL;
			case ENFILE:
				printf("Too many files are currently open in the system.\n");
				closedir(dir);
				break;
			case ENOENT:
				printf("Directory does not exist, or is an empty string.\n");
				closedir(dir);
				return NULL;
			case ENOMEM:
				printf("Insufficient memory to complete the operation..\n");
				closedir(dir);
				return NULL;
			default:
			case ENOTDIR:
				printf("\"%s\" is not a directory.\n",path);
				closedir(dir);
				return NULL;
		}
	}
	return dir;
}


/**
 * Writes the file statics in a formated string, given a pointer to the string.
 */
static int write_file(char *line,const char *mode,int num,const char *user,const char * group,int size,const char *date,const char*fl_name) {
	sprintf(line,"%s %3d %-4s %-4s %8d %12s %s\r\n",mode,num,user,group,size,date,fl_name);
	//free(line);
	return 0;
}

/**
 * Check if the given directory is none of ".", or ".."
 */
static bool is_special_dir(const char *dir) {
	if(dir==NULL)
		return TRUE;
	int len = strlen(dir);
	if(len>2)
		return FALSE;
	if(dir[0]!='.')
		return FALSE;
	if(len==1)
		return TRUE;
	if(dir[1]=='.')
		return TRUE;
	return FALSE;
}

/**
 * Write file statics in a line using the buffer from stat(...) primitive
 */
static bool get_file_info_stat(const char *file_name, char *line,struct stat *s_buff){
	char date[16];
	char mode[11]	= "----------";
	line[0]='\0';
	struct passwd * pass_info = getpwuid(s_buff->st_uid);
	if(pass_info!=NULL) {
		struct group * group_info = getgrgid(s_buff->st_gid);
		if(group_info!=NULL) {
			int b_mask = s_buff->st_mode & S_IFMT;
			if(b_mask == S_IFDIR) {
				mode[0]='d';
			} else if(b_mask == S_IFREG){
				mode[0]='-';
			} else {
				return FALSE;
			}
			mode[1] = (s_buff->st_mode & S_IRUSR)?'r':'-';
			mode[2] = (s_buff->st_mode & S_IWUSR)?'w':'-';
			mode[3] = (s_buff->st_mode & S_IXUSR)?'x':'-';
			mode[4] = (s_buff->st_mode & S_IRGRP)?'r':'-';
			mode[5] = (s_buff->st_mode & S_IWGRP)?'w':'-';
			mode[6] = (s_buff->st_mode & S_IXGRP)?'x':'-';
			mode[7] = (s_buff->st_mode & S_IROTH)?'r':'-';
			mode[8] = (s_buff->st_mode & S_IWOTH)?'w':'-';
			mode[9] = (s_buff->st_mode & S_IXOTH)?'x':'-';
			strftime(date,13,"%b %d %H:%M",localtime(&(s_buff->st_mtime)));

			write_file(
				line,mode,s_buff->st_nlink,
				pass_info->pw_name,
				group_info->gr_name,
				s_buff->st_size,date,
				file_name
			);
			return TRUE;
		}
	}
	return FALSE;
}

/**
 * Empty function , similara to python's "pass" operator.
 */
static void do_nothing() { if(TRUE==FALSE) do_nothing();}

/**
 * Writes the file statistics in a line "line"
 */
static bool get_file_info(const char *file_name, char *line){
	if(line==NULL)
		return FALSE;
	struct stat s_buff;
	if(is_special_dir(file_name))
		do_nothing();//return FALSE;
	int status = stat(file_name,&s_buff);
	if(status==0) {
		return get_file_info_stat(file_name,line,&s_buff);
	}
	return FALSE;
}

/**
 * Get and send the info for the current directory
 */
bool write_list(int sock, int client_sock, const char *current_dir) {
	
	if(client_sock>0) {
		if(sock!=client_sock) {
			send_repl(sock,REPL_150);
		}
	}
	else {
		if(sock!=client_sock) {
			send_repl(sock,REPL_425);
		}
		return FALSE;
	}
	DIR *dir = ensure_dir_exists(sock,current_dir);
	if(dir==NULL) {
		if(sock!=client_sock) {
			close(client_sock);
			send_repl(sock,REPL_451);
		}
		return FALSE;
	}
	
	char line[300];
	while(1) {
		struct dirent *d_next = readdir(dir);
		if(d_next==NULL)
			break;
		line[0]='\0';
		if(get_file_info(d_next->d_name,line)) {
			if(send_repl_client(client_sock,line)) {
				if(sock!=client_sock)
					send_repl(sock,REPL_451);
			}
		}
	}
	if(sock!=client_sock) {
		close(client_sock);
		send_repl(sock,REPL_226);
		//free(line);
	}
	//free(line);
	closedir(dir);
	return TRUE;
}

/**
 * Create a directory, called "new_dir"
 */
bool make_dir(int sock,const char *new_dir,char *reply) {
	
	struct stat s_buff;
	int status = stat(new_dir,&s_buff);
	if(status==0) {
		send_repl(sock,REPL_550);
		return FALSE;
	}
	status = mkdir(new_dir,0755);
	if(status!=0) {
		send_repl(sock,REPL_550);
		return FALSE;
	}
	reply[0]='\0';
	int len = sprintf(reply,REPL_257,new_dir);
	reply[len] ='\0';
	send_repl_len(sock,reply,len);
	return TRUE;
}

/**
 * Delete the directory called "removed_dir"
 */
bool remove_dir(int sock,const char *removed_dir) {
	if(is_special_dir(removed_dir)) {
		send_repl(sock,REPL_550);
		return FALSE;
	} 
	struct stat s_buff;
	int status = stat(removed_dir,&s_buff);
	if(status!=0) {
		send_repl(sock,REPL_550);
		return FALSE;
	} 
	int b_mask = s_buff.st_mode & S_IFMT;
	if(b_mask != S_IFDIR) {
		send_repl(sock,REPL_550);
		return FALSE;
	}
	status = rmdir(removed_dir);
	if(status!=0) {
		send_repl(sock,REPL_550);
		return FALSE;
	}
	send_repl(sock,REPL_250);
	return TRUE;
}

/**
 * Rename a file or directory. If operation is not successfull - return FALSE
 */
bool rename_fr(int sock,const char *from,const char *to) {
	if(is_special_dir(from)) {
		send_repl(sock,REPL_553);
		return FALSE;
	} 
	struct stat s_buff;
	int status = stat(from,&s_buff);
	if(status!=0) {
		send_repl(sock,REPL_553);
		return FALSE;
	} 
	status = stat(to,&s_buff);
	if(status==0) {
		send_repl(sock,REPL_553);
		return FALSE;
	} 
	int b_mask = s_buff.st_mode & S_IFMT;
	if(b_mask == S_IFDIR || b_mask == S_IFREG) {
		int status = rename(from,to);
		if(status!=0) {
			send_repl(sock,REPL_553);
			return FALSE;
		}
	} else {
		send_repl(sock,REPL_553);
		return FALSE;
	}
	send_repl(sock,REPL_250);
	return TRUE;
}

/**
 * Delete a file, given its name
 */
bool delete_file(int sock,const char *delete_file) {

	struct stat s_buff;
	int status = stat(delete_file,&s_buff);
	if(status!=0) {
		send_repl(sock,REPL_550);
		return FALSE;
	} 
	int b_mask = s_buff.st_mode & S_IFMT;
	if(b_mask != S_IFREG) {
		send_repl(sock,REPL_550);
		return FALSE;
	}
	status = unlink(delete_file);
	if(status!=0) {
		send_repl(sock,REPL_450);
		return FALSE;
	}
	send_repl(sock,REPL_250);
	return TRUE;
}

/**
 * Show stats about a file. If the file is a directory show stats about its content.
 */
bool stat_file(int sock, const char *file_path,char *reply) {
	char line[300];
	struct stat s_buff;
	int status = stat(file_path,&s_buff);
	if(status==0) {
		reply[0]='\0';
		int len = sprintf(reply,REPL_211_STATUS,file_path);
		send_repl_len(sock,reply,len);
		int b_mask = s_buff.st_mode & S_IFMT;
		if(b_mask == S_IFDIR) {
			if(getcwd(line,300)!=NULL) {	
				int status = chdir(file_path);
				if(status != 0) {
					send_repl(sock,REPL_450);
					//free(line);
					return FALSE;
				}
				else {
					if(!write_list(sock, sock, file_path)) {
						send_repl(sock,REPL_450);
						return FALSE;
					}
					int status = chdir(line);
					if(status!=0) {
						send_repl(sock,REPL_450);
						//free(line);
						return FALSE;
					}
				}
			} else {
				send_repl(sock,REPL_450);
				//free(line);
				return FALSE;
					
			}
		} else if(b_mask == S_IFREG){
			if(get_file_info_stat(file_path,line,&s_buff)) {
				if(send_repl_client(sock,line)) {
					send_repl(sock,REPL_450);
					//free(line);
					return FALSE;
				}
			}
		} 
		send_repl(sock,REPL_211_END);
	}
	else {
		send_repl(sock,REPL_450);
		return FALSE;
	}
	free(line);
	return TRUE;
}

/**
 * Change current working dir.
 */
bool change_dir(int sock,const char *parent_dir,char *current_dir,char *virtual_dir,char *data_buff) {
	DIR *dir = ensure_dir_exists(sock,data_buff);
	if(dir!=NULL) {
		closedir(dir);
		int status = chdir(current_dir);
		if(status==0) {
			int status = chdir(data_buff);
			if(status == 0) {
				if(getcwd(current_dir,MAXPATHLEN)!=NULL) {
					send_repl(sock,REPL_250);
					return TRUE;
				}
			}
		} 
	}
	send_repl(sock,REPL_550);
	return FALSE;
}

/**
 * Writes the contet of a file to the given client socket.
 * This is used for file download in ACTIVE mode.
 */
bool retrieve_file(int sock, int client_sock, int type, const char * file_name) {
	char read_buff[SENDBUFSIZE];
	if(client_sock>0) {
		//close(client_sock);
		send_repl(sock,REPL_150);
	}
	else {
		close(client_sock);
		send_repl(sock,REPL_425);
		free(read_buff);
		return FALSE;
	}
	struct stat s_buff;
	int status = stat(file_name,&s_buff);
	if(status!=0) {
		close(client_sock);
		send_repl(sock,REPL_450);
		free(read_buff);
		return FALSE;
	}
	int b_mask = s_buff.st_mode & S_IFMT;
	if(b_mask != S_IFREG){
		close(client_sock);
		send_repl(sock,REPL_451);
		free(read_buff);
		return FALSE;
	}
	char mode[3] ="r ";
	switch(type){
		case 1:
		case 3:
		case 4:
			mode[1]='b';
			break;
		case 2:
		default:
			mode[1]='t';
	}

	int fpr = open(file_name,O_RDONLY);
	if(fpr<0) {
		close(client_sock);
		send_repl(sock,REPL_451);
		free(mode);
		free(read_buff);
		return FALSE;
	}
	
	// make transfer unbuffered
	int opt = fcntl(client_sock, F_GETFL, 0);
        if (fcntl(client_sock, F_SETFL, opt | O_ASYNC) == -1)
		{
			send_repl(sock,REPL_426);
			close_connection(client_sock);
			free(read_buff);
			return FALSE;
		}
	while(1){
		int len = read(fpr,read_buff,SENDBUFSIZE);
		if(len>0) {
			send_repl_client_len(client_sock,read_buff,len);
		}
		else {
			break;
		}
	}
	close(fpr);
	send_repl(sock,REPL_226);
	close_connection(client_sock);
	return TRUE;
}

/**
 * Writes a file on the server, given an open client socket descriptor.
 * We are waiting for file contents on this descriptor.
 */
bool stou_file(int sock, int client_sock, int type, int fpr) {
	char read_buff[SENDBUFSIZE];
	if(fpr<0) {
		close_connection(client_sock);
		send_repl(sock,REPL_451);
		free(read_buff);
		return FALSE;
	}
	// make transfer unbuffered
	int opt = fcntl(client_sock, F_GETFL, 0);
        if (fcntl(client_sock, F_SETFL, opt | O_ASYNC) == -1) {
		send_repl(sock,REPL_426);
		close_connection(client_sock);
		free(read_buff);
		return FALSE;
	}
	while(1){
		
		int len = recv(client_sock,read_buff,SENDBUFSIZE,0);
		if(len>0) {
			write(fpr,read_buff,len);
		}
		else {
			break;
		}
	}
	close_connection(client_sock);
	close(fpr);
	send_repl(sock,REPL_226);
	return TRUE;
}

/**
 * Writes a file, given a file path(name and location) and open client socket.
 */
bool store_file(int sock, int client_sock, int type, const char * file_name) {
	char read_buff[SENDBUFSIZE];
	if(client_sock>0) {
		//close(client_sock);
		send_repl(sock,REPL_150);
	}
	else {
		close_connection(client_sock);
		send_repl(sock,REPL_425);
		free(read_buff);
		return FALSE;
	}
	struct stat s_buff;
	int status = stat(file_name,&s_buff);
	if(status==0) {
		int b_mask = s_buff.st_mode & S_IFMT;
		if(b_mask != S_IFREG){
			free(read_buff);
			close_connection(client_sock);
			send_repl(sock,REPL_451);
			
			return FALSE;
		}
	}
	char mode[3] ="w ";
	switch(type){
		case 1:
		case 3:
		case 4:
			mode[1]='b';
			break;
		case 2:
		default:
			mode[1]='t';
	}

	int fpr = open(file_name,O_WRONLY|O_CREAT,0644);
	return stou_file(sock, client_sock,type,fpr);
}
