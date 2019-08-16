# nginx container
with
- lua
- sticky session with patch so that cookie do not include port number into hash string to share route cookie between multiple services on the backend
- shibboleth with patch so that SAML uid copy into nginx remote_user variable
- headers-more
- support ajp backend
- dynamic name resolving (jdomain)


