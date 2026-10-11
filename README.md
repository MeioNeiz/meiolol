# meiolol

League of Legends champ select pick recommender, in Zig. See CLAUDE.md and docs/.

```bash
zig build test
zig build meiolol -- champions                      # backend
zig build meiolol-app -- suggest --role mid --enemy Ahri,Jinx
deploy/box.sh status                                # crawler on the gpu-box PC
```
