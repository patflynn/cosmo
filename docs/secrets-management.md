# **Secrets Management Guide**

This repository uses [Agenix](https://github.com/ryantm/agenix) to manage encrypted secrets (like user passwords, API keys, etc.).

Unlike standard Nix configuration, secrets require **imperative** steps to create and edit.

## **Architecture**

* **Tool**: agenix CLI (installed via home/dev.nix or nix develop).  
* **Keys**:  
  * **User Keys**: Allow *humans* to decrypt/edit secrets (defined in secrets/keys.nix).  
  * **Host Keys**: Allow *machines* to decrypt secrets at boot (defined in secrets/keys.nix).  
* **ACL**: Access rules are defined in secrets/secrets.nix.  
* **Storage**: Encrypted binary files live in secrets/\*.age.

## **Workflows**

### **1\. Editing an Existing Secret**

To change the content of an existing secret (e.g., updating a password):

\# Enter the dev shell to ensure agenix is installed  
nix develop

\# Edit the file (opens in your default $EDITOR)  
agenix \-e secrets/user-password.age

### **2\. Adding a New Secret**

To track a new secret file:

1. **Define Access**: Edit secrets/secrets.nix to add the new file and specify who can read it.  
   \# secrets/secrets.nix  
   {  
     "new-secret.age".publicKeys \= keys.users \++ keys.hosts;  
   }

2. **Create the File**:  
   agenix \-e secrets/new-secret.age

3. **Reference in Nix**: Update your NixOS module to use the secret.  
   \# In a module file:  
   age.secrets.new-secret.file \= ../secrets/new-secret.age;

### **3\. Adding a New Host (Rekeying)**

If you add a new machine (e.g., new-host) that needs to access secrets:

1. **Get Host Key**: Run cat /etc/ssh/ssh\_host\_ed25519\_key.pub on the new machine.  
2. **Update Keys**: Add the public key string to secrets/keys.nix.  
3. **Update ACL**: Ensure the new host key is included in the relevant lists in secrets/secrets.nix.  
4. **Rekey**: Run the rekey command to update the encryption for all affected files.  
   agenix \--rekey

5. **Commit**: Commit the updated .age files.

## **Troubleshooting**

"Identity not found" when editing:  
Ensure your personal SSH private key is loaded in your agent:  
ssh-add \~/.ssh/id\_ed25519  
