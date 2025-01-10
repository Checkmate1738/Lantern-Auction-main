import hashlib
import os
import ecdsa


# Utility functions
def sha256(data):
    return hashlib.sha256(data.encode('utf-8')).hexdigest()


# Merkle Tree Class
class MerkleTree:
    def __init__(self, leaves):
        self.leaves = [sha256(leaf) for leaf in leaves]
        self.tree = self.build_tree(self.leaves)

    def build_tree(self, leaves):
        tree = [leaves]
        while len(tree[-1]) > 1:
            layer = []
            for i in range(0, len(tree[-1]), 2):
                left = tree[-1][i]
                right = tree[-1][i + 1] if i + 1 < len(tree[-1]) else left
                layer.append(sha256(left + right))
            tree.append(layer)
        return tree

    def get_root(self):
        return self.tree[-1][0] if self.tree else None

    def generate_proof(self, index):
        proof = []
        layer_index = 0
        while layer_index < len(self.tree) - 1:
            sibling_index = index ^ 1
            if sibling_index < len(self.tree[layer_index]):
                proof.append(self.tree[layer_index][sibling_index])
            index //= 2
            layer_index += 1
        return proof


# Wallet Class
class Wallet:
    def __init__(self):
        self.private_key = ecdsa.SigningKey.generate(curve=ecdsa.SECP256k1)
        self.public_key = self.private_key.get_verifying_key()
        self.address = sha256(self.public_key.to_string().hex())

    def sign_transaction(self, transaction):
        return self.private_key.sign(transaction.encode('utf-8'))

    def verify_signature(self, transaction, signature):
        return self.public_key.verify(signature, transaction.encode('utf-8'))


# Example usage
if __name__ == "__main__":
    # Create wallets
    wallet1 = Wallet()
    wallet2 = Wallet()

    print("Wallet 1 Address:", wallet1.address)
    print("Wallet 2 Address:", wallet2.address)

    # Initial balances as leaves
    balances = [f"{wallet1.address}:100", f"{wallet2.address}:50"]

    # Build Merkle tree
    merkle_tree = MerkleTree(balances)
    print("Merkle Root:", merkle_tree.get_root())

    # Generate a proof for wallet1
    proof = merkle_tree.generate_proof(0)
    print("Merkle Proof for Wallet 1:", proof)

    # Sign a transaction
    transaction = f"Transfer 10 from {wallet1.address} to {wallet2.address}"
    signature = wallet1.sign_transaction(transaction)
    print("Transaction Signature:", signature.hex())

    # Verify the transaction
    is_valid = wallet1.verify_signature(transaction, signature)
    print("Is the signature valid?", is_valid)
