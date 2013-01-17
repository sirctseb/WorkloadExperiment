library DataServer;
import "dart:io";
import "package:logging/logging.dart";

void main() {
  Server server = new Server();
  // print messages to console
  Logger.root.on.record.add((LogRecord record) {
    print(record.message);
  });
}

class Server {
  HttpServer server = new HttpServer();
  WebSocketHandler wsHandler = new WebSocketHandler();
  File dataFile = null;
  int trialNumber = 0;
  int subjectNumber = 0;
  bool logEvents = false;
  OutputStream stream;
  
  Server() {
    
    server.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
    
    wsHandler.onOpen = (WebSocketConnection conn) {
      
      Logger.root.info('new connection');
      
      conn.onMessage = (String message) {
        Logger.root.finest("data server received message: $message");
        
        if(message.startsWith("end trial")) {
          Logger.root.info("data server received end trial message");
          
          // set log events flag to stop logging
          logEvents = false;
          
          // close stream
          stream.close();
        }
        
        if(logEvents) {
          Logger.root.finest("data server logging message");
          
          // write mouse click location to file
          stream.writeString("$message\n");
        }
        
        // check for subject number command
        if(message.startsWith("subject")) {
          
          // get subject number
          subjectNumber = int.parse(message.split(" ")[1]);
          
          Logger.root.info("data server got subject number: $subjectNumber");
          
          // reset trial number
          trialNumber = 0;
        }
        
        if(message.startsWith("start trial")) {
          Logger.root.info("data server received start trial message");
          
          // set trial number
          trialNumber++;
          
          // create data file object
          dataFile = new File.fromPath(new Path("output/subject$subjectNumber/trial$trialNumber/data.txt"));
          
          // create directory
          new Directory("output/subject$subjectNumber/trial$trialNumber").createSync(recursive:true);
          
          // open file stream
          stream = dataFile.openOutputStream();
          
          // set log event flag
          logEvents = true;
        }
      };
      
      conn.onClosed = (int status, String reason) {
        print('closed with $status for $reason');
        Logger.root.info(new Date.now().toString());
      };
    };
    
    server.listen('127.0.0.1', 8000);
  }
  
  void createFile() {
    // create a file for the current subject and trial number
  }
}