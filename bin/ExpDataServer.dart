import "dart:io";

void main() {
  
  HttpServer server = new HttpServer();
  WebSocketHandler wsHandler = new WebSocketHandler();
  File dataFile = new File.fromPath(new Path("output/data.txt"));
  OutputStream stream;
  server.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
  
  wsHandler.onOpen = (WebSocketConnection conn) {
    // open file stream
    stream = dataFile.openOutputStream();
    
    print('new connection');
    
    conn.onMessage = (message) {
      print("mouse click at: $message");
      // write mouse click location to file
      stream.writeString("$message\n");
    };
    
    conn.onClosed = (int status, String reason) {
      print('closed with $status for $reason');
      
      // close stream
      stream.close();
    };
  };
  
  server.listen('127.0.0.1', 8000);
}