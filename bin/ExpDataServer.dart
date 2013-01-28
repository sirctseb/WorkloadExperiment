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
  Process recordingProcess;
  
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
          
          // stop recording
          if(recordingProcess != null) {
            Logger.root.info("killing recording");
            recordingProcess.kill();
            // TODO if not ^, send message to client
            recordingProcess = null;
          }
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
          Path dataFilePath = new Path("output/subject$subjectNumber/trial$trialNumber/data.txt");
          dataFile = new File.fromPath(dataFilePath);
          
          // create directory
          new Directory("output/subject$subjectNumber/trial$trialNumber").createSync(recursive:true);
          
          // open file stream
          stream = dataFile.openOutputStream();
          
          // write task description to separate file
          new File.fromPath(dataFilePath.directoryPath.append("task.txt")).writeAsString(message);
          
          // start recording
          Logger.root.info("starting recording");
          Logger.root.info("cwd: ${new Directory.current().toString()}");
          //Process.start("sox", ["-d", "output/subject$subjectNumber/trial$trialNumber/audio.mp3"])
          Process.start("/opt/local/bin/sox", ["-d", "output/subject$subjectNumber/trial$trialNumber/audio.mp3"])
          .then((Process process) {
            Logger.root.info("recording started");
            recordingProcess = process;
            // TODO send message to client that recording started
            // TODO on error send message that we're not recording
          });
          
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