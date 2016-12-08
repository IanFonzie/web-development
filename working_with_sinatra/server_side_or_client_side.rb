# Gemfiles are server side because they are where we list the 
# rubygems/libraries that a project will use. In other words
# it is used by bundler, which is Ruby's dependency management system, to
# install libraries (rubygems) needed to runt he program

# ruby files are server side and they contain the logic needed to execute
# code when a client makes a request to the server. In other words,
# ruby files ar ethe core of a sinatra application and the code within them
# runs on the server while handling incoming requests

# Stylesheets are client side because they determine how the client will render
# the information that it receives from the server, they also determine how information
# is displayed by the client. In other words they are interpreted by the browser(rendered)
# as instruction for how to display a web page

#javascript is usually server side, it can be used to process requests from a server using
# a client side callback function though it can also be used to manipulate the DOM when a certain
# event occurs. In other words the code within JS files is evaluated by
# the javascript interepreter within a web browser (client) to add behavior
# to web pages.

# View templates are server side because they are templates that are embedded with
# Ruby code that has been provided by the server. In other words the code within these
# files is evaluated on the server to generate a response that will then be sent to the client.

# Note what about HTML in ERB. Still client side because they msut be processed by
# a program on the server before being sent to the client. Templates we used are sometimes
# referred to as server side templates to differentiate them from client side templates to differentiate
# them from client side tempaltes. Client side tempaltes are used by rich javascript applications
# to render a tempalte directly on the client without it needing to first be processed by a server.
