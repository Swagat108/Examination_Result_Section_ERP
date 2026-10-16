import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { MODULES } from "../../modules";

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
      <section className="login-hero">
        <span className="brand">
          <span className="brand-mark">UE</span>
          University ERP
        </span>
        <div className="rule" />
        <h2>One place for the whole campus.</h2>
        <p>Admissions, academics, attendance, fees, exams and placements, working from the same data.</p>
        <div className="chips">
          {MODULES.map((m) => (
            <span key={m.key}>{m.label}</span>
          ))}
        </div>
      </section>
      <div className="login-form-side">
        <form onSubmit={submit} className="card login-card">
          <h1>Sign in</h1>
          <p className="muted">Use your university account to continue.</p>
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
          <div className="dev-accounts">Dev accounts (password123): {DEV_ACCOUNTS.join(", ")}</div>
        </form>
      </div>
    </div>
  );
}
