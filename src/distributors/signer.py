from eth_account import Account
from eth_account.messages import encode_defunct
from eth_abi import encode
from eth_utils import keccak, to_checksum_address

# ==============================
# CONFIG
# ==============================

MASTER_PRIVATE_KEY = "0x"
MASTER_ADDRESS = Account.from_key(MASTER_PRIVATE_KEY).address

# ABI types for Share struct
SHARE_ABI_TYPES = [
    "uint256",
    "address",
    "uint256",
    "uint256",
    "uint256",
    "uint256",
    "uint256",
]

# ==============================
# DATA
# ==============================

shares = [
    {
        "id": "100",
        "owner": "0x4CFD0573feDe55f980724373469A32dd7a1619c5",
        "tge": "1000000000000000000",
        "startTime": "1769604783",
        "initialAmount": "500000000000000000",
        "amountPerSecond": "10000000",
        "totalCap": "1000000000000000000",
    },
    {
        "id": "200",
        "owner": "0x4CFD0573feDe55f980724373469A32dd7a1619c5",
        "tge": "1000000000000000000",
        "startTime": "1769604783",
        "initialAmount": "100000000000000000",
        "amountPerSecond": "100000000",
        "totalCap": "5000000000000000000",
    },
]

# ==============================
# SIGNING FUNCTION
# ==============================

def sign_share(share: dict):
    # Convert values to correct Python types
    values = [
        int(share["id"]),
        to_checksum_address(share["owner"]),
        int(share["tge"]),
        int(share["startTime"]),
        int(share["initialAmount"]),
        int(share["amountPerSecond"]),
        int(share["totalCap"]),
    ]

    # abi.encode(Share)
    abi_encoded = encode(SHARE_ABI_TYPES, values)

    # keccak256(abi.encode(Share))
    struct_hash = keccak(abi_encoded)

    # Apply Ethereum signed message prefix
    message = encode_defunct(primitive=struct_hash)

    # Sign with master key
    signed = Account.sign_message(message, MASTER_PRIVATE_KEY)

    return {
        "abiEncoded": abi_encoded.hex(),
        "hash": struct_hash.hex(),
        "signature": signed.signature.hex(),
        "signer": Account.recover_message(message, signature=signed.signature),
    }

# ==============================
# RUN
# ==============================

for s in shares:
    result = sign_share(s)
    print(f"Share ID: {s['id']}")
    print(f"Signer:   {result['signer']}")
    print(f"Sig:      {result['signature']}")
    print("-" * 60)
