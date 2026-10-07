# Session lock investigation

User supplied bcacce77-96e9-415c-b1b0-fd39eadbb666 log. Prior non-finite profile rejection, kit missing and module-load yield errors are absent. Kit loaded with 31 pieces.

Read only DataStore inspection in confirmed Astral Forge Studio used the configured player store and Player_10916707683 key. Returned only lock metadata; no profile contents exposed or modified. Lock timestamp 1791256342, age 602 seconds at first inspection; expiry 600 seconds. Document.isLocked compares age < 600. Therefore this lock has naturally expired, with no forced theft or altered timeout.

The log's retries describe earlier ownership contention, not the numeric schema error. Full rejoin load confirmation remains outstanding. Eight legacy monetization IDs are still unconfigured and remain unavailable. No publication or saved-data writes performed.
