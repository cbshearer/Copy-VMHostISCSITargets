Copy all Static iSCSI targets from one host to all HBAs another using PowerShell / PowerCLI

I ran into a situation where I needed to replace the HBAs on my hosts and had a lot of static iSCSI targets that needed to be added to each HBA on a bunch of servers. I created this script which gets all HBAs on a given host and puts them on all of the HBAs on another.

Because I was doing these HBA replacements one at a time, there is no logic to apply this to all HBAs on all hosts, although it could be added.

If you only want to add them to one HBA on the other, see the comments on lines 8-11.
