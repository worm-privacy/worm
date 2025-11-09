.PHONY=sepolia anvil


anvil:
	forge script --rpc-url http://127.0.0.1:8545 script/Beth.s.sol:BETHScript --via-ir --private-key 0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d --broadcast
	# BETH: 0xCfEB869F69431e42cdB54A4F4f105C19C080A601
	# WORM: 0x254dffcd3277C0b1660F6d42EFbB754edaBAbC2B
	# Staking: 0xC89Ce4735882C9F0f0FE26686c53074E09B0D550
