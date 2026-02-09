import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import {
    ShoppingBag,
    Clock,
    CheckCircle,
    IndianRupee,
    TrendingUp,
    Printer,
    RefreshCw,
    ArrowRight
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'

export default function Dashboard() {
    const navigate = useNavigate()
    const [stats, setStats] = useState({
        totalOrders: 0,
        pendingOrders: 0,
        readyOrders: 0,
        todayRevenue: 0
    })
    const [recentOrders, setRecentOrders] = useState([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        fetchDashboardData()

        // Set up realtime subscription for instant updates
        const channel = supabase
            .channel('dashboard-realtime')
            .on('postgres_changes',
                { event: '*', schema: 'public', table: 'orders' },
                (payload) => {
                    console.log('Dashboard realtime update:', payload)
                    fetchDashboardData()
                }
            )
            .subscribe((status) => {
                console.log('Dashboard subscription status:', status)
            })

        return () => {
            supabase.removeChannel(channel)
        }
    }, [])

    const fetchDashboardData = async () => {
        try {
            // Fetch all orders
            const { data: orders, error } = await supabase
                .from('orders')
                .select(`
          *,
          students (name, roll_number, dept)
        `)
                .order('created_at', { ascending: false })

            if (error) throw error

            // Calculate stats
            const today = new Date().toISOString().split('T')[0]
            const todayOrders = orders.filter(o =>
                o.created_at.startsWith(today)
            )

            setStats({
                totalOrders: orders.length,
                pendingOrders: orders.filter(o => o.status === 'pending' || o.status === 'processing').length,
                readyOrders: orders.filter(o => o.status === 'ready').length,
                todayRevenue: todayOrders.reduce((sum, o) => sum + Number(o.cost), 0)
            })

            // Get recent 5 orders
            setRecentOrders(orders.slice(0, 5))
        } catch (error) {
            console.error('Error fetching dashboard data:', error)
        } finally {
            setLoading(false)
        }
    }

    const getStatusBadge = (status) => {
        const statusConfig = {
            pending: { label: 'Pending', class: 'pending' },
            processing: { label: 'Processing', class: 'processing' },
            printing: { label: 'Printing', class: 'printing' },
            ready: { label: 'Ready', class: 'ready' },
            completed: { label: 'Completed', class: 'completed' },
            cancelled: { label: 'Cancelled', class: 'cancelled' }
        }
        const config = statusConfig[status] || { label: status, class: 'pending' }
        return <span className={`status-badge ${config.class}`}>{config.label}</span>
    }

    const formatDate = (dateString) => {
        const date = new Date(dateString)
        return date.toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        })
    }

    if (loading) {
        return (
            <div className="loading-container">
                <div className="loading-spinner"></div>
            </div>
        )
    }

    return (
        <div className="fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <div>
                    <h1 style={{ fontSize: '24px', fontWeight: '700', marginBottom: '4px' }}>Dashboard</h1>
                    <p style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>Welcome back! Here's your overview.</p>
                </div>
                <div className="live-indicator">
                    <span className="live-dot"></span>
                    Live Updates
                </div>
            </div>

            {/* Stats Grid */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon blue">
                        <ShoppingBag size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>{stats.totalOrders}</h3>
                        <p>Total Orders</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon orange">
                        <Clock size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>{stats.pendingOrders}</h3>
                        <p>Pending Orders</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon green">
                        <CheckCircle size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>{stats.readyOrders}</h3>
                        <p>Ready for Pickup</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon purple">
                        <IndianRupee size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>₹{stats.todayRevenue.toLocaleString()}</h3>
                        <p>Today's Revenue</p>
                    </div>
                </div>
            </div>

            {/* Recent Orders */}
            <div className="card">
                <div className="card-header">
                    <h2>Recent Orders</h2>
                    <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => navigate('/orders')}
                    >
                        View All <ArrowRight size={16} />
                    </button>
                </div>

                {recentOrders.length === 0 ? (
                    <div className="empty-state">
                        <Printer size={48} />
                        <h3>No orders yet</h3>
                        <p>Orders from students will appear here</p>
                    </div>
                ) : (
                    <div className="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Order ID</th>
                                    <th>Student</th>
                                    <th>Amount</th>
                                    <th>Status</th>
                                    <th>Date</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentOrders.map(order => (
                                    <tr key={order.id}>
                                        <td style={{ fontWeight: '600', color: 'var(--primary-blue)' }}>
                                            {order.order_id}
                                        </td>
                                        <td>
                                            <div>
                                                <div style={{ fontWeight: '500' }}>{order.students?.name || 'Unknown'}</div>
                                                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                                                    {order.students?.roll_number} • {order.students?.dept}
                                                </div>
                                            </div>
                                        </td>
                                        <td style={{ fontWeight: '600' }}>₹{Number(order.cost).toLocaleString()}</td>
                                        <td>{getStatusBadge(order.status)}</td>
                                        <td style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                                            {formatDate(order.created_at)}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        </div>
    )
}
