import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";

const DEV_ACCOUNTS = ["admin", "faculty", "student", "accountant", "placement"];

export default function LoginPage() {
  const { user, login } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState("admin");
  const [password, setPassword] = useState("password123");
  const [error, setError] = useState("");

  if (user) return <Navigate to="/" replace />;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      await login(username, password);
      navigate("/");
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <div className="login-page">
      <header className="masthead">
        <div className="container">
          <span className="wordmark">University ERP</span>
        </div>
      </header>
      <div className="login-body">
      <form onSubmit={submit} className="card login-card">
        <h1>Sign in</h1>
        <div className="gold-rule" />
        <label>
          Username
          <input value={username} onChange={(e) => setUsername(e.target.value)} />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit">Sign in</button>
        <p className="muted caption">Dev accounts (password123): {DEV_ACCOUNTS.join(", ")}</p>
      </form>
      </div>
    </div>
  );
}
