# nginx container
with
- lua
- sticky session with patch so that cookie do not include port number into hash string to share route cookie between multiple services on the upstream
- shibboleth with patch so that SAML uid copy into nginx remote_user variable
- headers-more
- support ajp upstream
- dynamic name resolving for upstream (jdomain)
- discover upstream from DNS SRV record (resolveMK)

The Dockerfile was derived from https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081.
Thank you hermanbanken.
