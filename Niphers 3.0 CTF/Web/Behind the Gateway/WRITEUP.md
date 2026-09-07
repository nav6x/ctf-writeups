# Behind the Gateway (Niphers 3.0 CTF, web)

This looked like an ordinary web challenge and got tricky fast. The admin panel was blocked by the gateway and direct access gave 403. Headers and various URL encodings didn't help; some bypasses reached the backend but returned 404, which told me the gateway and backend were parsing the URL differently. Appending `foo` to the path was what finally worked, a gateway/backend URL-parsing desync, and that got me into the admin panel, where I found a cache warmer and a hidden cache-view endpoint. The flag path itself was still blocked.

The breakthrough was CL.TE request smuggling. I smuggled a request to the cache warmer that fetched `/admin-dashboard/flag` and stored the result in the shared cache. Then I opened `/cache-view?path=/admin-dashboard/flag` and read it straight out of the poisoned cache.

Flag: `$N1PH€RSxTCTF{smuggl3d_my_way_int0_the_po1s0n3d_cach3}`
