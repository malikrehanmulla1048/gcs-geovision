import { useState } from "react";
import axios from "axios";

export default function Login({ setToken }) {
    const [username, setUser] = useState("");
    const [password, setPass] = useState("");

    const login = async () => {
        const res = await axios.post("http://localhost:3000/auth", {
            username,
            password
        });

        localStorage.setItem("token", res.data.token);
        setToken(res.data.token);
    };

    return (
        <div className="login">
            <h2>Login</h2>
            <input placeholder="Username" onChange={e => setUser(e.target.value)} />
            <input type="password" placeholder="Password" onChange={e => setPass(e.target.value)} />
            <button onClick={login}>Login</button>
        </div>
    );
}
