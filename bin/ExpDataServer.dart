library DataServer;
import "dart:io";
import "dart:json";
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
  var blockNumber = 0;
  bool logEvents = false;
  OutputStream stream;
  Process recordingProcess;
  
  String get subjectDirStr => "output/subject$subjectNumber";
  String get blockDirStr => "$subjectDirStr/block$blockNumber";
  String get blockDescPathStr => "$blockDirStr/block.txt";
  String get trialDirStr => "$blockDirStr/trial$trialNumber";
  String get trialDescPathStr => "$trialDirStr/task.txt";
  String get dataFilePathStr => "$trialDirStr/data.txt";
  String get surveyPathStr => "$blockDirStr/survey.txt";
  String get weightsPathStr => "$subjectDirStr/weights.txt";
  
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
            if(recordingProcess.kill()) {
              Logger.root.info("recording process succsssfully killed");
            } else {
              Logger.root.info("killing recording failed. already dead?");
            }
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
        if(message.startsWith("set: ")) {
          
          // get subject number
          Map info = parse(message.substring("set: ".length));
          // read subject if it was sent
          if(info.containsKey("subject")) {
            subjectNumber = info["subject"];
            Logger.root.info("data server got subject number: $subjectNumber");
          }
          // read block if it was sent
          if(info.containsKey("block")) {
            blockNumber = info["block"];
            Logger.root.info("data server got block number: $blockNumber");
            // write block description if it was sent
            if(info.containsKey("blockDesc")) {
              Logger.root.info("data server got block description");
              
              // make file object
              File blockDescFile = new File.fromPath(new Path(blockDescPathStr));
              
              Logger.root.info("made block desc file object; ensuring dir exists");
              
              // make sure directory exists
              new Directory(blockDirStr).createSync(recursive:true);
              
              Logger.root.info("ensured dir exists, writing file contents");
              
              // write block description to file
              blockDescFile.writeAsStringSync(stringify(info["blockDesc"]));
              Logger.root.info("data server wrote block description to file");
            }
          }
          // read trial if it was sent
          if(info.containsKey("trial")) {
            trialNumber = info["trial"];
            Logger.root.info("data server got trial number $trialNumber");
          }
        }
        
        if(message.startsWith("survey: ")) {
          Logger.root.info("data server received survey results");
          
          // TODO make sure directory exists?
          
          // create file object
          File surveyFile = new File.fromPath(new Path(surveyPathStr));
          
          // write survey to file
          surveyFile.writeAsString(message);
          
        }
        
        if(message.startsWith("weights: ")) {
          Logger.root.info("data serve received weights");
          
          // TODO make sure directory exists?
          
          // create file object
          File weightsFile = new File.fromPath(new Path(weightsPathStr));
          
          // write weights to file
          weightsFile.writeAsString(message);
        }
        
        if(message.startsWith("start trial")) {
          Logger.root.info("data server received start trial message");
          
          // create data file object
          Path dataFilePath = new Path(dataFilePathStr);
          dataFile = new File.fromPath(dataFilePath);
          
          // create directory
          new Directory(trialDirStr).createSync(recursive:true);
          
          // open file stream
          stream = dataFile.openOutputStream();
          
          // write task description to separate file
          new File.fromPath(dataFilePath.directoryPath.append("task.txt")).writeAsString(message);
          
          // start recording
          Logger.root.info("starting recording");
          Logger.root.info("cwd: ${new Directory.current().toString()}");
          //Process.start("sox", ["-d", "output/subject$subjectNumber/trial$trialNumber/audio.mp3"])
          Process.start("/opt/local/bin/sox", ["-d", "$trialDirStr/audio.mp3"])
          .then((Process process) {
            Logger.root.info("recording started");
            recordingProcess = process;
            // read all stdout and stderr data so it doesn't break the recording
            // TODO log to an invisible div?
            recordingProcess.stdout.onData = () {
              process.stdout.read();
            };
            recordingProcess.stderr.onData = () {
              process.stderr.read();
            };
            // TODO send message to client that recording started
            // TODO on error send message that we're not recording
          });
          
          // set log event flag
          logEvents = true;
        }
      };
      
      conn.onClosed = (int status, String reason) {
        print('closed with $status for $reason');
        Logger.root.info(new DateTime.now().toString());
      };
    };
    
    server.listen('127.0.0.1', 8000);
  }
  
  void createFile() {
    // create a file for the current subject and trial number
  }
}