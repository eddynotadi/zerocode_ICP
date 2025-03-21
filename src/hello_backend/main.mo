import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Buffer "mo:base/Buffer";

actor CodeBridge {
  private let apiUrl = "https://zerocode-backend.azurewebsites.net/";

  public type HttpHeader = {
    name : Text;
    value : Text;
  };

  public type HttpMethod = { #get; #post; };
  
  public type TransformRawResponseFunction = shared query (HttpResponse) -> async HttpResponse;

  public type HttpResponse = {
    status : Nat;
    headers : [HttpHeader];
    body : Blob;
  };

  public type RequestData = {
    prompt : Text;
    max_tokens : Nat;
  };

  public type GenerationResponse = {
    response : Text;
  };

  type Credit = {
    principal : Text;
    balance : Nat;
  };
  
  type Image = {
    principal : Text;
    data : Blob;
  };

  stable var credits: [Credit] = [];
  stable var images: [Image] = [];

  private let ic : actor {
    http_request : {
      url : Text;
      max_response_bytes : ?Nat64;
      headers : [HttpHeader];
      body : ?Blob;
      method : HttpMethod;
      transform : ?TransformRawResponseFunction;
    } -> async HttpResponse;
  } = actor("aaaaa-aa");

  // Generate text from backend
  public func generateText(request : RequestData) : async GenerationResponse {
    Debug.print("Sending prompt to external service: " # request.prompt);

    let requestBodyText = "{\"prompt\": \"" # request.prompt # "\", \"max_tokens\": " # Nat.toText(request.max_tokens) # "}";
    let requestBodyBlob = Text.encodeUtf8(requestBodyText);

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" }
    ];

    Cycles.add(200_000_000_000);

    let httpResponse = await ic.http_request({
      url = apiUrl # "/generate";
      method = #post;
      headers = requestHeaders;
      body = ?requestBodyBlob;
      max_response_bytes = ?Nat64.fromNat(10 * 1024 * 1024);
      transform = null;
    });

    { response = switch (Text.decodeUtf8(httpResponse.body)) {
      case (null) "Error: Failed to decode response body";
      case (?text) text;
    }}
  };

  // Helper function to parse JSON field
  private func parseJsonField(text: Text, marker: Text) : Nat {
    let pattern = #text(marker);
    switch (Text.split(text, pattern).next()) {
      case null { 0 };
      case (?before) { Text.size(before) + Text.size(marker) };
    };
  };

  // Helper function to find character
  private func findChar(text: Text, char: Char) : Nat {
    var index = 0;
    let textIter = Text.toIter(text);
    
    for (c in textIter) {
      if (c == char) return index;
      index += 1;
    };
    0
  };

  // Health check
  public query func healthCheck() : async Text {
    "Code Bridge Canister is running - Connected to: " # apiUrl
  };

  // Image processing function
  public shared func send_http_post_request(image : Blob, style : Blob, principalId : Text) : async Blob {
    let balance = await getBalance(principalId);
    if (balance == 0) {
      Debug.print("Insufficient credits for principal: " # principalId);
      return Blob.fromArray([]);
    };

    reduceCredit(principalId);

    let imageData = Blob.toArray(image);
    let styleData = Blob.toArray(style);
    
    let buffer = Buffer.Buffer<Nat8>(styleData.size() + imageData.size());
    for (byte in styleData.vals()) buffer.add(byte);
    for (byte in imageData.vals()) buffer.add(byte);
    
    Cycles.add(21_850_258_000);

    try {
      let response = await ic.http_request({
        url = "https://tabella.my.id/api/generate";
        method = #post;
        headers = [
          { name = "User-Agent"; value = "request_backend" },
          { name = "Content-Type"; value = "application/octet-stream" },
          { name = "Idempotency-Key"; value = generateUUID() }
        ];
        body = ?Blob.fromArray(Buffer.toArray(buffer));
        max_response_bytes = null;
        transform = null;
      });

      await SaveImages(response.body, principalId);
      response.body
    } catch (e) {
      Debug.print("Error in HTTP request: " # Error.message(e));
      Blob.fromArray([])
    };
  };

  // --- Support Functions ---
  private func generateUUID() : Text { "uuid-placeholder" };

  private func reduceCredit(principalId: Text) {
    credits := Array.map<Credit, Credit>(credits, func(c) {
      if (c.principal == principalId and c.balance > 0) {
        { principal = c.principal; balance = c.balance - 1 }
      } else {
        c
      }
    });
  };

  private func getBalance(principalId: Text) : async Nat {
    for (c in credits.vals()) {
      if (c.principal == principalId) return c.balance;
    };
    0
  };

  private func SaveImages(blob: Blob, principalId: Text) : async () {
    let buffer = Buffer.Buffer<Image>(images.size() + 1);
    for (img in images.vals()) buffer.add(img);
    buffer.add({ principal = principalId; data = blob });
    images := Buffer.toArray(buffer);
  };
}