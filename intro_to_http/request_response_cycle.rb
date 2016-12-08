# 1. The required components of an HTTP request are the HTTP method and the Path. Additional optional 
# components are query strings/parameters, request headers and the request body

# 2. The required components of the responses are the status. optional components 
# consist of the responses headers and body.

# 3. The users actions determine if a request will use the GET or POST method. 
# If the user is request information from a server i.e. Requesting a website using 
# the browser’s URL bar then they are issuing an HTTP GET request. they are generally 
# thought of as “read only” operations though there are some exceptions to this 
# rule i.e. a website that tracks how many times it is viewed. GET is still appropriate 
# in this circumstance because the main content of the page doesn’t change. 

# POSTs involve changing values that are stored on the server and most HTML 
# forms that submit their values to the server will use them. Again there are 
# certain exceptions to this rule, like search forms since they are only viewing data 
# on the server and not changing it  If they are planning to push data from the client to
# the server then they are most likely using an HTTP POST request.

# 4. The host component of the URL is not included as part of an HTTP request, 
# it is only used to establish a connection between a host and a client. Only 
# path and parameters are included in the request
