import { NavLink, useNavigate } from 'react-router-dom'
import {
    LayoutDashboard,
    ShoppingBag,
    BarChart3,
    LogOut,
    Printer,
    User
} from 'lucide-react'

export default function Sidebar() {
    const navigate = useNavigate()
    const admin = JSON.parse(localStorage.getItem('admin') || '{}')

    const handleLogout = () => {
        localStorage.removeItem('admin')
        navigate('/login')
    }

    const navItems = [
        { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
        { path: '/orders', icon: ShoppingBag, label: 'Orders' },
        { path: '/analytics', icon: BarChart3, label: 'Analytics' },
    ]

    return (
        <aside className="sidebar">
            <div className="sidebar-logo">
                <div style={{
                    width: '40px',
                    height: '40px',
                    background: 'linear-gradient(135deg, var(--primary-blue), var(--primary-orange))',
                    borderRadius: '10px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white'
                }}>
                    <Printer size={22} />
                </div>
                <div>
                    <h1>XeroFlow</h1>
                    <span>Admin Portal</span>
                </div>
            </div>

            <nav className="sidebar-nav">
                {navItems.map(item => (
                    <NavLink
                        key={item.path}
                        to={item.path}
                        className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
                    >
                        <item.icon size={20} />
                        {item.label}
                    </NavLink>
                ))}
            </nav>

            <div className="sidebar-footer">
                <div className="admin-info">
                    <div className="admin-avatar">
                        {admin.name?.charAt(0).toUpperCase() || 'A'}
                    </div>
                    <div className="admin-details" style={{ flex: 1 }}>
                        <h4>{admin.name || 'Admin'}</h4>
                        <span>{admin.email || 'admin@xeroflow.com'}</span>
                    </div>
                    <button
                        onClick={handleLogout}
                        className="btn-icon btn-secondary"
                        title="Logout"
                        style={{
                            padding: '8px',
                            background: 'transparent',
                            border: 'none',
                            cursor: 'pointer',
                            color: 'var(--text-muted)'
                        }}
                    >
                        <LogOut size={18} />
                    </button>
                </div>
            </div>
        </aside>
    )
}
