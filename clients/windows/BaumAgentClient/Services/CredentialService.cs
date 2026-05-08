using Windows.Security.Credentials;

namespace BaumAgent.Services;

/// <summary>
/// Stores the BaumAgent URL and API token in the Windows Credential Manager (PasswordVault).
/// </summary>
public class CredentialService
{
    private const string Resource = "BaumAgentClient";
    private const string UrlKey = "BaumAgent_Url";
    private const string TokenKey = "BaumAgent_Token";
    private const string UserEmailKey = "BaumAgent_UserEmail";
    private const string UserDisplayKey = "BaumAgent_UserDisplay";

    private readonly PasswordVault _vault = new();

    public bool HasCredentials()
    {
        try
        {
            _vault.Retrieve(Resource, TokenKey);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public void Save(string url, string token, string userEmail, string displayName)
    {
        SetSecret(UrlKey, url);
        SetSecret(TokenKey, token);
        SetSecret(UserEmailKey, userEmail);
        SetSecret(UserDisplayKey, displayName);
    }

    public (string Url, string Token) GetCredentials()
    {
        var url = GetSecret(UrlKey) ?? throw new InvalidOperationException("BaumAgent URL not stored.");
        var token = GetSecret(TokenKey) ?? throw new InvalidOperationException("API token not stored.");
        return (url, token);
    }

    public string? GetUserEmail() => GetSecret(UserEmailKey);
    public string? GetUserDisplayName() => GetSecret(UserDisplayKey);

    public void Clear()
    {
        Remove(UrlKey);
        Remove(TokenKey);
        Remove(UserEmailKey);
        Remove(UserDisplayKey);
    }

    private void SetSecret(string key, string value)
    {
        Remove(key);
        _vault.Add(new PasswordCredential(Resource, key, value));
    }

    private string? GetSecret(string key)
    {
        try
        {
            var cred = _vault.Retrieve(Resource, key);
            cred.RetrievePassword();
            return cred.Password;
        }
        catch { return null; }
    }

    private void Remove(string key)
    {
        try
        {
            var cred = _vault.Retrieve(Resource, key);
            _vault.Remove(cred);
        }
        catch { }
    }
}
