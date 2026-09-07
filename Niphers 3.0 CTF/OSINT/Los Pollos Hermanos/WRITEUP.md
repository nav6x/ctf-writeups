# Los Pollos Hermanos (Niphers 3.0 CTF, osint)

The thread starts with a GitHub alias, `lospolloshermanos165`, which is just three Breaking Bad-themed repos sitting there. The one named after Gus Fring has a file that was created and then deleted in the history, and deleted isn't gone, so pulling the earlier commit gives up an author email, `heisenbergthecook436@gmail.com`.

GHunt and Epieos didn't turn up much on that address, so I went straight for the Google Calendar iCal feed tied to the account, which was fully public. The only event on it read "mankatha bike chasing scene." That's the iconic Ajith bike chase from the 2011 Tamil film *Mankatha*. Watching the scene, the bike is black and the helmet literally says "exorcist," which is the whole flag.

Flag: `N1PH€RSxTCTF{BLACK_EXORCIST}`
