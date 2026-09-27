```python
import socket
from datetime import datetime, date

import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# ==============================================================================
# CẤU HÌNH STREAMLIT
# ==============================================================================

st.set_page_config(
    page_title="Quản Lý Tour Trọn Gói",
    page_icon="✈️",
    layout="wide"
)


# ==============================================================================
# KẾT NỐI AIVEN MYSQL
# ==============================================================================

# Ưu tiên lấy thông tin từ Streamlit Secrets.
# Nếu chạy local và chưa có secrets thì sử dụng thông tin bên dưới.

try:
    DB_USER = st.secrets["mysql"]["user"]
    DB_PASSWORD = st.secrets["mysql"]["password"]
    DB_HOST = st.secrets["mysql"]["host"]
    DB_PORT = st.secrets["mysql"]["port"]
    DB_NAME = st.secrets["mysql"]["database"]

except Exception:

    # ==========================================================
    # THÔNG TIN AIVEN CỦA EM
    # ==========================================================

    DB_USER = "avnadmin"
    DB_PASSWORD = "AVNS_zBDlzsF9I5fC-EdWcl0"
    DB_HOST = "mysql-19728385-npmaihuong-927f.b.aivencloud.com"
    DB_PORT = 27942
    DB_NAME = "defaultdb"


# ==============================================================================
# LÀM SẠCH THÔNG TIN KẾT NỐI
# ==============================================================================

DB_USER = str(DB_USER).strip()
DB_PASSWORD = str(DB_PASSWORD).strip()
DB_HOST = str(DB_HOST).strip()
DB_NAME = str(DB_NAME).strip()
DB_PORT = int(DB_PORT)


# ==============================================================================
# KIỂM TRA KẾT NỐI AIVEN
# ==============================================================================

with st.expander("🔧 Kiểm tra kết nối Aiven", expanded=False):

    st.write("**HOST:**", repr(DB_HOST))
    st.write("**PORT:**", repr(DB_PORT))
    st.write("**DATABASE:**", repr(DB_NAME))
    st.write("**USER:**", repr(DB_USER))

    if DB_HOST != DB_HOST.strip():

        st.error(
            "HOST đang có khoảng trắng. "
            "Hệ thống đã tự động loại bỏ."
        )

    else:

        st.success("HOST hợp lệ.")

    if st.button("🔍 Kiểm tra DNS Aiven"):

        try:

            ip_address = socket.gethostbyname(DB_HOST)

            st.success(
                f"DNS OK - Host Aiven trỏ tới IP: {ip_address}"
            )

        except Exception as e:

            st.error(
                f"DNS ERROR: Không phân giải được hostname Aiven.\n\n{e}"
            )


# ==============================================================================
# DATABASE URL
# ==============================================================================

DATABASE_URL = URL.create(
    drivername="mysql+pymysql",
    username=DB_USER,
    password=DB_PASSWORD,
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
)


# ==============================================================================
# DATABASE ENGINE
# ==============================================================================

@st.cache_resource
def get_db_engine():

    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        connect_args={
            "connect_timeout": 15
        },
        pool_size=5,
        max_overflow=5,
    )

    return engine


# ==============================================================================
# KIỂM TRA DATABASE
# ==============================================================================

def test_database_connection():

    try:

        engine = get_db_engine()

        with engine.connect() as conn:

            result = conn.execute(
                text("SELECT 1")
            )

            result.fetchone()

        return True, "Kết nối Aiven MySQL thành công!"

    except Exception as e:

        return False, str(e)


# ==============================================================================
# TẠO DATABASE
# ==============================================================================

def init_db():

    engine = get_db_engine()

    # ------------------------------------------------------------------
    # BẢNG TOURS
    # ------------------------------------------------------------------

    create_tours = """
    CREATE TABLE IF NOT EXISTS tours (

        id INT AUTO_INCREMENT PRIMARY KEY,

        tour_name VARCHAR(200) NOT NULL,

        destination VARCHAR(200) NOT NULL,

        departure_date DATE NOT NULL,

        return_date DATE NOT NULL,

        duration INT NOT NULL,

        price DECIMAL(12,2) NOT NULL,

        max_people INT NOT NULL,

        transport VARCHAR(100),

        hotel VARCHAR(200),

        meals VARCHAR(200),

        tour_guide VARCHAR(150),

        description TEXT,

        created_at DATETIME NOT NULL

    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """


    # ------------------------------------------------------------------
    # BẢNG KHÁCH HÀNG
    # ------------------------------------------------------------------

    create_customers = """
    CREATE TABLE IF NOT EXISTS customers (

        id INT AUTO_INCREMENT PRIMARY KEY,

        full_name VARCHAR(150) NOT NULL,

        phone VARCHAR(30) NOT NULL,

        email VARCHAR(150),

        address VARCHAR(255),

        created_at DATETIME NOT NULL

    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """


    # ------------------------------------------------------------------
    # BẢNG BOOKING
    # ------------------------------------------------------------------

    create_bookings = """
    CREATE TABLE IF NOT EXISTS bookings (

        id INT AUTO_INCREMENT PRIMARY KEY,

        created_at DATETIME NOT NULL,

        customer_id INT NOT NULL,

        tour_id INT NOT NULL,

        quantity INT NOT NULL,

        total_price DECIMAL(12,2) NOT NULL,

        payment_status VARCHAR(50) NOT NULL,

        FOREIGN KEY (customer_id)
            REFERENCES customers(id),

        FOREIGN KEY (tour_id)
            REFERENCES tours(id)

    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """


    # ------------------------------------------------------------------
    # THỰC THI TẠO BẢNG
    # ------------------------------------------------------------------

    with engine.begin() as conn:

        conn.exec_driver_sql(create_tours)

        conn.exec_driver_sql(create_customers)

        conn.exec_driver_sql(create_bookings)


# ==============================================================================
# KHỞI TẠO DATABASE
# ==============================================================================

db_connected = False

try:

    init_db()

    db_connected = True

except Exception as e:

    db_connected = False

    st.error(
        "❌ Không thể kết nối Aiven MySQL."
    )

    st.code(
        str(e),
        language="text"
    )

    st.warning(
        "Kiểm tra lại HOST, PORT, USER, PASSWORD "
        "và DATABASE trong Aiven."
    )


# ==============================================================================
# SESSION STATE
# ==============================================================================

if "booking_cart" not in st.session_state:

    st.session_state.booking_cart = {}


if "admin_logged_in" not in st.session_state:

    st.session_state.admin_logged_in = False


# ==============================================================================
# HÀM ĐỌC DỮ LIỆU TỪ MYSQL
# ==============================================================================

def read_query(sql, params=None):

    try:

        engine = get_db_engine()

        with engine.connect() as conn:

            df = pd.read_sql(
                text(sql),
                conn,
                params=params or {}
            )

        return df

    except Exception as e:

        st.error(
            f"Lỗi đọc dữ liệu từ Aiven: {e}"
        )

        return pd.DataFrame()


# ==============================================================================
# HÀM GHI DỮ LIỆU
# ==============================================================================

def execute_query(sql, params=None):

    try:

        engine = get_db_engine()

        with engine.begin() as conn:

            conn.execute(
                text(sql),
                params or {}
            )

        return True

    except Exception as e:

        st.error(
            f"Lỗi lưu dữ liệu: {e}"
        )

        return False


# ==============================================================================
# HÀM LẤY LỊCH SỬ BOOKING
# ==============================================================================

def load_booking_history():

    sql = """
    SELECT

        b.id AS ID,

        b.created_at AS `Thời gian`,

        c.full_name AS `Khách hàng`,

        c.phone AS `Số điện thoại`,

        t.tour_name AS `Tên tour`,

        t.destination AS `Điểm đến`,

        b.quantity AS `Số khách`,

        b.total_price AS `Tổng tiền`,

        b.payment_status AS `Trạng thái`

    FROM bookings b

    JOIN customers c
        ON b.customer_id = c.id

    JOIN tours t
        ON b.tour_id = t.id

    ORDER BY b.created_at DESC
    """

    return read_query(sql)


# ==============================================================================
# SIDEBAR
# ==============================================================================

st.sidebar.title("✈️ QUẢN LÝ TOUR")

st.sidebar.caption(
    "Hệ thống quản lý tour trọn gói"
)

page = st.sidebar.radio(
    "📋 Chọn trang hệ thống",

    [
        "🏠 Tổng quan",
        "🚌 Quản lý Tour",
        "👤 Khách hàng",
        "📋 Đặt Tour",
        "🧾 Hóa đơn",
        "🔑 Admin"
    ]
)


# ==============================================================================
# TRANG TỔNG QUAN
# ==============================================================================

if page == "🏠 Tổng quan":

    st.title(
        "✈️ HỆ THỐNG QUẢN LÝ TOUR TRỌN GÓI"
    )

    st.caption(
        "Quản lý tour - khách hàng - booking - thanh toán - doanh thu"
    )

    if db_connected:

        st.success(
            "🟢 Aiven MySQL: ĐÃ KẾT NỐI"
        )

    else:

        st.error(
            "🔴 Aiven MySQL: CHƯA KẾT NỐI"
        )

    st.markdown("---")

    # ------------------------------------------------------------------
    # LẤY DỮ LIỆU
    # ------------------------------------------------------------------

    df_tours = read_query(
        "SELECT * FROM tours"
    )

    df_customers = read_query(
        "SELECT * FROM customers"
    )

    df_bookings = read_query(
        "SELECT * FROM bookings"
    )


    # ------------------------------------------------------------------
    # KPI
    # ------------------------------------------------------------------

    col1, col2, col3, col4 = st.columns(4)

    with col1:

        st.metric(
            "🚌 Tổng số tour",
            len(df_tours)
        )

    with col2:

        st.metric(
            "👤 Khách hàng",
            len(df_customers)
        )

    with col3:

        st.metric(
            "📋 Booking",
            len(df_bookings)
        )

    with col4:

        if not df_bookings.empty:

            revenue = df_bookings[
                "total_price"
            ].sum()

        else:

            revenue = 0

        st.metric(
            "💰 Doanh thu",
            f"{revenue:,.0f} VNĐ"
        )


    st.markdown("---")


    # ------------------------------------------------------------------
    # DANH SÁCH TOUR
    # ------------------------------------------------------------------

    st.subheader(
        "🚌 Các tour đang kinh doanh"
    )

    if not df_tours.empty:

        display_tours = df_tours[
            [
                "id",
                "tour_name",
                "destination",
                "departure_date",
                "return_date",
                "duration",
                "price",
                "max_people"
            ]
        ].copy()

        display_tours.columns = [
            "ID",
            "Tên tour",
            "Điểm đến",
            "Khởi hành",
            "Kết thúc",
            "Số ngày",
            "Giá tour",
            "Số khách tối đa"
        ]

        st.dataframe(
            display_tours,
            use_container_width=True,
            hide_index=True
        )

    else:

        st.info(
            "Chưa có tour. "
            "Hãy vào Quản lý Tour để thêm tour."
        )


# ==============================================================================
# QUẢN LÝ TOUR
# ==============================================================================

elif page == "🚌 Quản lý Tour":

    st.title(
        "🚌 QUẢN LÝ TOUR TRỌN GÓI"
    )

    st.caption(
        "Tạo và quản lý các chương trình tour trọn gói"
    )

    tab1, tab2 = st.tabs(
        [
            "➕ Tạo Tour",
            "📋 Danh sách Tour"
        ]
    )


    # ==================================================================
    # TAB TẠO TOUR
    # ==================================================================

    with tab1:

        st.subheader(
            "➕ Tạo chương trình tour mới"
        )

        with st.form(
            "create_tour_form"
        ):

            col1, col2 = st.columns(2)

            with col1:

                tour_name = st.text_input(
                    "🏷️ Tên tour",
                    placeholder="Ví dụ: Tour Đà Lạt 3 ngày 2 đêm"
                )

                destination = st.text_input(
                    "📍 Điểm đến",
                    placeholder="Đà Lạt"
                )

                departure_date = st.date_input(
                    "🚌 Ngày khởi hành",
                    date.today()
                )

                return_date = st.date_input(
                    "🏠 Ngày kết thúc",
                    date.today()
                )

                duration = st.number_input(
                    "📅 Số ngày",
                    min_value=1,
                    value=3
                )

                price = st.number_input(
                    "💰 Giá tour / khách (VNĐ)",
                    min_value=0,
                    value=3000000,
                    step=100000
                )


            with col2:

                max_people = st.number_input(
                    "👥 Số khách tối đa",
                    min_value=1,
                    value=30
                )

                transport = st.selectbox(
                    "🚌 Phương tiện",
                    [
                        "Xe du lịch",
                        "Máy bay",
                        "Tàu hỏa",
                        "Tàu cao tốc",
                        "Xe + máy bay",
                        "Khác"
                    ]
                )

                hotel = st.text_input(
                    "🏨 Khách sạn",
                    placeholder="Khách sạn 3 sao / 4 sao..."
                )

                meals = st.text_input(
                    "🍽️ Ăn uống",
                    placeholder="5 bữa chính + 2 bữa sáng..."
                )

                tour_guide = st.text_input(
                    "🧑‍💼 Hướng dẫn viên",
                    placeholder="Nguyễn Văn A"
                )


            description = st.text_area(
                "📝 Nội dung / lịch trình tour",
                placeholder=(
                    "Mô tả lịch trình, điểm tham quan, "
                    "dịch vụ bao gồm trong tour..."
                )
            )


            submit = st.form_submit_button(
                "💾 LƯU TOUR",
                use_container_width=True
            )


            if submit:

                if not tour_name:

                    st.warning(
                        "⚠️ Vui lòng nhập tên tour."
                    )

                elif not destination:

                    st.warning(
                        "⚠️ Vui lòng nhập điểm đến."
                    )

                elif return_date < departure_date:

                    st.error(
                        "❌ Ngày kết thúc không được trước ngày khởi hành."
                    )

                else:

                    sql = """
                    INSERT INTO tours
                    (
                        tour_name,
                        destination,
                        departure_date,
                        return_date,
                        duration,
                        price,
                        max_people,
                        transport,
                        hotel,
                        meals,
                        tour_guide,
                        description,
                        created_at
                    )

                    VALUES
                    (
                        :tour_name,
                        :destination,
                        :departure_date,
                        :return_date,
                        :duration,
                        :price,
                        :max_people,
                        :transport,
                        :hotel,
                        :meals,
                        :tour_guide,
                        :description,
                        :created_at
                    )
                    """

                    success = execute_query(
                        sql,
                        {
                            "tour_name": tour_name,
                            "destination": destination,
                            "departure_date": departure_date,
                            "return_date": return_date,
                            "duration": duration,
                            "price": price,
                            "max_people": max_people,
                            "transport": transport,
                            "hotel": hotel,
                            "meals": meals,
                            "tour_guide": tour_guide,
                            "description": description,
                            "created_at": datetime.now()
                        }
                    )

                    if success:

                        st.success(
                            "🎉 Tạo tour thành công!"
                        )

                        st.balloons()


    # ==================================================================
    # TAB DANH SÁCH TOUR
    # ==================================================================

    with tab2:

        st.subheader(
            "📋 Danh sách tour"
        )

        df = read_query(
            """
            SELECT
                id,
                tour_name,
                destination,
                departure_date,
                return_date,
                duration,
                price,
                max_people,
                transport,
                hotel,
                meals,
                tour_guide,
                description
            FROM tours
            ORDER BY departure_date ASC
            """
        )


        if not df.empty:

            df_display = df.copy()

            df_display.columns = [
                "ID",
                "Tên tour",
                "Điểm đến",
                "Khởi hành",
                "Kết thúc",
                "Số ngày",
                "Giá tour",
                "Số khách tối đa",
                "Phương tiện",
                "Khách sạn",
                "Ăn uống",
                "HDV",
                "Mô tả"
            ]

            st.dataframe(
                df_display,
                use_container_width=True,
                hide_index=True
            )

        else:

            st.info(
                "Chưa có tour nào."
            )


# ==============================================================================
# KHÁCH HÀNG
# ==============================================================================

elif page == "👤 Khách hàng":

    st.title(
        "👤 QUẢN LÝ KHÁCH HÀNG"
    )


    tab1, tab2 = st.tabs(
        [
            "➕ Thêm khách hàng",
            "📋 Danh sách khách hàng"
        ]
    )


    # ==================================================================
    # THÊM KHÁCH
    # ==================================================================

    with tab1:

        with st.form(
            "customer_form"
        ):

            full_name = st.text_input(
                "👤 Họ và tên"
            )

            phone = st.text_input(
                "📱 Số điện thoại"
            )

            email = st.text_input(
                "📧 Email"
            )

            address = st.text_input(
                "🏠 Địa chỉ"
            )

            submit = st.form_submit_button(
                "💾 Lưu khách hàng",
                use_container_width=True
            )


            if submit:

                if not full_name:

                    st.warning(
                        "⚠️ Vui lòng nhập họ tên."
                    )

                elif not phone:

                    st.warning(
                        "⚠️ Vui lòng nhập số điện thoại."
                    )

                else:

                    success = execute_query(
                        """
                        INSERT INTO customers
                        (
                            full_name,
                            phone,
                            email,
                            address,
                            created_at
                        )

                        VALUES
                        (
                            :full_name,
                            :phone,
                            :email,
                            :address,
                            :created_at
                        )
                        """,

                        {
                            "full_name": full_name,
                            "phone": phone,
                            "email": email,
                            "address": address,
                            "created_at": datetime.now()
                        }
                    )


                    if success:

                        st.success(
                            "✅ Thêm khách hàng thành công!"
                        )


    # ==================================================================
    # DANH SÁCH KHÁCH
    # ==================================================================

    with tab2:

        df_customers = read_query(
            """
            SELECT
                id,
                full_name,
                phone,
                email,
                address,
                created_at
            FROM customers
            ORDER BY created_at DESC
            """
        )


        if not df_customers.empty:

            df_customers.columns = [
                "ID",
                "Họ tên",
                "Số điện thoại",
                "Email",
                "Địa chỉ",
                "Ngày tạo"
            ]

            st.dataframe(
                df_customers,
                use_container_width=True,
                hide_index=True
            )

        else:

            st.info(
                "Chưa có khách hàng."
            )


# ==============================================================================
# ĐẶT TOUR
# ==============================================================================

elif page == "📋 Đặt Tour":

    st.title(
        "📋 ĐẶT TOUR TRỌN GÓI"
    )

    st.caption(
        "Thực hiện booking tour cho khách hàng"
    )


    customers = read_query(
        """
        SELECT
            id,
            full_name,
            phone
        FROM customers
        ORDER BY full_name
        """
    )


    tours = read_query(
        """
        SELECT
            id,
            tour_name,
            destination,
            departure_date,
            duration,
            price,
            max_people
        FROM tours
        WHERE departure_date >= CURRENT_DATE
        ORDER BY departure_date
        """
    )


    if customers.empty:

        st.warning(
            "⚠️ Chưa có khách hàng. "
            "Hãy thêm khách hàng trước."
        )

    elif tours.empty:

        st.warning(
            "⚠️ Hiện chưa có tour sắp khởi hành."
        )

    else:

        col1, col2 = st.columns(2)


        # ==============================================================
        # CHỌN KHÁCH
        # ==============================================================

        with col1:

            customer_options = (
                customers["full_name"]
                + " - "
                + customers["phone"]
            ).tolist()


            selected_customer = st.selectbox(
                "👤 Chọn khách hàng",
                customer_options
            )


            selected_customer_index = (
                customer_options.index(
                    selected_customer
                )
            )


            customer_id = int(
                customers.iloc[
                    selected_customer_index
                ]["id"]
            )


        # ==============================================================
        # CHỌN TOUR
        # ==============================================================

        with col2:

            tour_options = (
                tours["tour_name"]
                + " - "
                + tours["destination"]
            ).tolist()


            selected_tour = st.selectbox(
                "🚌 Chọn tour",
                tour_options
            )


            selected_tour_index = (
                tour_options.index(
                    selected_tour
                )
            )


            tour = tours.iloc[
                selected_tour_index
            ]


            tour_id = int(
                tour["id"]
            )


        st.markdown("---")


        # ==============================================================
        # THÔNG TIN TOUR
        # ==============================================================

        col1, col2, col3, col4 = st.columns(4)


        with col1:

            st.info(
                f"📍 Điểm đến\n\n"
                f"**{tour['destination']}**"
            )


        with col2:

            st.info(
                f"📅 Khởi hành\n\n"
                f"**{tour['departure_date']}**"
            )


        with col3:

            st.info(
                f"⏱️ Thời gian\n\n"
                f"**{tour['duration']} ngày**"
            )


        with col4:

            st.info(
                f"💰 Giá tour\n\n"
                f"**{tour['price']:,.0f} VNĐ**"
            )


        st.markdown("---")


        # ==============================================================
        # KIỂM TRA SỐ CHỖ
        # ==============================================================

        booked_df = read_query(
            """
            SELECT
                COALESCE(
                    SUM(quantity),
                    0
                ) AS booked_people
            FROM bookings
            WHERE tour_id = :tour_id
            """,

            {
                "tour_id": tour_id
            }
        )


        booked_people = int(
            booked_df.iloc[0]["booked_people"]
        )


        remaining = (
            int(tour["max_people"])
            - booked_people
        )


        st.metric(
            "🪑 Số chỗ còn lại",
            f"{remaining} / {tour['max_people']}"
        )


        if remaining <= 0:

            st.error(
                "❌ Tour đã đủ số lượng khách."
            )

        else:

            quantity = st.number_input(
                "👥 Số lượng khách",
                min_value=1,
                max_value=remaining,
                value=1
            )


            total_price = (
                float(tour["price"])
                * quantity
            )


            st.metric(
                "💰 TỔNG TIỀN TOUR",
                f"{total_price:,.0f} VNĐ"
            )


            payment_status = st.selectbox(
                "💳 Trạng thái thanh toán",
                [
                    "Chưa thanh toán",
                    "Đã đặt cọc",
                    "Đã thanh toán"
                ]
            )


            if st.button(
                "🎫 XÁC NHẬN ĐẶT TOUR",
                use_container_width=True
            ):

                success = execute_query(
                    """
                    INSERT INTO bookings
                    (
                        created_at,
                        customer_id,
                        tour_id,
                        quantity,
                        total_price,
                        payment_status
                    )

                    VALUES
                    (
                        :created_at,
                        :customer_id,
                        :tour_id,
                        :quantity,
                        :total_price,
                        :payment_status
                    )
                    """,

                    {
                        "created_at": datetime.now(),
                        "customer_id": customer_id,
                        "tour_id": tour_id,
                        "quantity": quantity,
                        "total_price": total_price,
                        "payment_status": payment_status
                    }
                )


                if success:

                    st.success(
                        "🎉 Đặt tour thành công!"
                    )

                    st.success(
                        f"Tổng thanh toán: "
                        f"{total_price:,.0f} VNĐ"
                    )

                    st.balloons()


# ==============================================================================
# HÓA ĐƠN
# ==============================================================================

elif page == "🧾 Hóa đơn":

    st.title(
        "🧾 QUẢN LÝ HÓA ĐƠN"
    )


    df_history = load_booking_history()


    if not df_history.empty:

        # ==============================================================
        # KPI
        # ==============================================================

        total_revenue = df_history[
            "Tổng tiền"
        ].sum()


        total_customers = df_history[
            "Số khách"
        ].sum()


        paid_revenue = df_history[
            df_history["Trạng thái"]
            == "Đã thanh toán"
        ]["Tổng tiền"].sum()


        col1, col2, col3 = st.columns(3)


        with col1:

            st.metric(
                "💰 Tổng giá trị booking",
                f"{total_revenue:,.0f} VNĐ"
            )


        with col2:

            st.metric(
                "👥 Tổng số khách",
                f"{total_customers}"
            )


        with col3:

            st.metric(
                "✅ Đã thanh toán",
                f"{paid_revenue:,.0f} VNĐ"
            )


        st.markdown("---")


        st.subheader(
            "📋 Danh sách booking"
        )


        st.dataframe(
            df_history,
            use_container_width=True,
            hide_index=True
        )


        # ==============================================================
        # CẬP NHẬT THANH TOÁN
        # ==============================================================

        st.markdown("---")

        st.subheader(
            "💳 Cập nhật trạng thái thanh toán"
        )


        invoice_id = st.number_input(
            "Nhập ID booking",
            min_value=1,
            step=1
        )


        new_status = st.selectbox(
            "Trạng thái mới",
            [
                "Chưa thanh toán",
                "Đã đặt cọc",
                "Đã thanh toán"
            ]
        )


        if st.button(
            "💾 Cập nhật"
        ):

            success = execute_query(
                """
                UPDATE bookings

                SET payment_status = :status

                WHERE id = :booking_id
                """,

                {
                    "status": new_status,
                    "booking_id": invoice_id
                }
            )


            if success:

                st.success(
                    "✅ Cập nhật trạng thái thành công!"
                )


    else:

        st.info(
            "Hệ thống chưa có booking nào."
        )


# ==============================================================================
# ADMIN
# ==============================================================================

elif page == "🔑 Admin":

    st.title(
        "🔑 TRANG QUẢN TRỊ"
    )


    # ==================================================================
    # LOGIN
    # ==================================================================

    if not st.session_state.admin_logged_in:

        with st.form(
            "admin_login"
        ):

            password = st.text_input(
                "🔐 Mật khẩu quản trị",
                type="password"
            )


            login = st.form_submit_button(
                "🔑 Đăng nhập"
            )


            if login:

                if password == "123456":

                    st.session_state.admin_logged_in = True

                    st.success(
                        "✅ Đăng nhập thành công!"
                    )

                    st.rerun()

                else:

                    st.error(
                        "❌ Mật khẩu không chính xác!"
                    )


        st.warning(
            "Vui lòng đăng nhập để xem thống kê."
        )

        st.stop()


    # ==================================================================
    # ĐÃ ĐĂNG NHẬP
    # ==================================================================

    col1, col2 = st.columns(
        [4, 1]
    )


    with col1:

        st.success(
            "🟢 Quyền Quản trị viên đã được xác thực."
        )


    with col2:

        if st.button(
            "🔒 Đăng xuất"
        ):

            st.session_state.admin_logged_in = False

            st.rerun()


    # ==================================================================
    # TABS ADMIN
    # ==================================================================

    tab1, tab2, tab3 = st.tabs(
        [
            "🚌 Danh sách Tour",
            "💰 Doanh thu & Booking",
            "📊 Phân tích"
        ]
    )


    # ==================================================================
    # TAB 1 - TOUR
    # ==================================================================

    with tab1:

        st.subheader(
            "🚌 Danh sách chương trình tour"
        )


        df_tours = read_query(
            """
            SELECT
                id,
                tour_name,
                destination,
                departure_date,
                return_date,
                duration,
                price,
                max_people,
                transport,
                hotel,
                meals,
                tour_guide
            FROM tours
            ORDER BY departure_date
            """
        )


        if not df_tours.empty:

            df_tours.columns = [
                "ID",
                "Tên tour",
                "Điểm đến",
                "Khởi hành",
                "Kết thúc",
                "Số ngày",
                "Giá",
                "Số khách tối đa",
                "Phương tiện",
                "Khách sạn",
                "Ăn uống",
                "HDV"
            ]


            st.dataframe(
                df_tours,
                use_container_width=True,
                hide_index=True
            )

        else:

            st.info(
                "Chưa có tour."
            )


    # ==================================================================
    # TAB 2 - DOANH THU
    # ==================================================================

    with tab2:

        st.subheader(
            "💰 Doanh thu & lịch sử booking"
        )


        df_history = load_booking_history()


        if not df_history.empty:

            total_revenue = df_history[
                "Tổng tiền"
            ].sum()


            total_people = df_history[
                "Số khách"
            ].sum()


            total_bookings = len(
                df_history
            )


            col1, col2, col3 = st.columns(3)


            with col1:

                st.metric(
                    "💰 Tổng doanh thu",
                    f"{total_revenue:,.0f} VNĐ"
                )


            with col2:

                st.metric(
                    "🎫 Tổng booking",
                    total_bookings
                )


            with col3:

                st.metric(
                    "👥 Tổng khách",
                    total_people
                )


            st.markdown("---")


            # ==========================================================
            # DOANH THU THEO NGÀY
            # ==========================================================

            st.subheader(
                "📅 Doanh thu theo ngày"
            )


            df_history["Thời gian"] = pd.to_datetime(
                df_history["Thời gian"]
            )


            df_history["Ngày"] = (
                df_history["Thời gian"]
                .dt.date
            )


            daily_revenue = (
                df_history
                .groupby("Ngày")["Tổng tiền"]
                .sum()
                .reset_index()
            )


            daily_revenue.columns = [
                "Ngày",
                "Doanh thu"
            ]


            col1, col2 = st.columns(
                [1.5, 1]
            )


            with col1:

                st.bar_chart(
                    daily_revenue.set_index(
                        "Ngày"
                    )["Doanh thu"]
                )


            with col2:

                st.dataframe(
                    daily_revenue.style.format(
                        {
                            "Doanh thu":
                            "{:,.0f} VNĐ"
                        }
                    ),
                    use_container_width=True,
                    hide_index=True
                )


            st.markdown("---")


            st.subheader(
                "📋 Lịch sử booking"
            )


            st.dataframe(
                df_history,
                use_container_width=True,
                hide_index=True
            )


        else:

            st.info(
                "Chưa có booking."
            )


    # ==================================================================
    # TAB 3 - PHÂN TÍCH
    # ==================================================================

    with tab3:

        st.subheader(
            "📊 Thống kê & Phân tích tour"
        )


        df_anal = load_booking_history()


        if not df_anal.empty:

            # ==========================================================
            # TOUR ĐƯỢC ĐẶT NHIỀU NHẤT
            # ==========================================================

            tour_quantity = (
                df_anal
                .groupby("Tên tour")["Số khách"]
                .sum()
            )


            best_tour = tour_quantity.idxmax()


            best_tour_quantity = (
                tour_quantity.max()
            )


            # ==========================================================
            # ĐIỂM ĐẾN ĐƯỢC QUAN TÂM NHẤT
            # ==========================================================

            destination_quantity = (
                df_anal
                .groupby("Điểm đến")["Số khách"]
                .sum()
            )


            best_destination = (
                destination_quantity.idxmax()
            )


            best_destination_quantity = (
                destination_quantity.max()
            )


            # ==========================================================
            # TOUR CÓ DOANH THU CAO NHẤT
            # ==========================================================

            tour_revenue = (
                df_anal
                .groupby("Tên tour")["Tổng tiền"]
                .sum()
            )


            revenue_tour = (
                tour_revenue.idxmax()
            )


            revenue_tour_value = (
                tour_revenue.max()
            )


            # ==========================================
```
