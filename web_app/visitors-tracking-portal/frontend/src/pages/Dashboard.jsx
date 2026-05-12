import { useEffect, useState } from "react";
import axios from "axios";

export default function Dashboard({ token, setToken }) {
    const [visitors, setVisitors] = useState([]);

    const fetchVisitors = async () => {
        const res = await axios.get("http://localhost:3000/visitors", {
            headers: { Authorization: token }
        });
        setVisitors(res.data);
    };

    const scan = async () => {
        await axios.post("http://localhost:3000/scan", {}, {
            headers: { Authorization: token }
        });
        fetchVisitors();
    };

    const logout = () => {
        localStorage.removeItem("token");
        setToken(null);
    };

    useEffect(() => {
        fetchVisitors();
    }, []);

    return (
        <div className="dashboard">
            <h1>AI Visitor Dashboard</h1>
            <button onClick={scan}>Scan Visitor</button>
            <button onClick={logout}>Logout</button>

            <ul>
                {visitors.map((v, i) => (
                    <li key={i}>
                        {v.name} - {v.time} ({v.confidence}%)
                    </li>
                ))}
            </ul>
        </div>
    );
}
