"""
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Step 5: Streamlit App — Loan Application Manual Review
    
    IMPORTANT: Uses fully qualified table names since Streamlit runtime
    does not inherit USE SCHEMA from session context.
    
    Deploy via: CREATE STREAMLIT in your schema with KAPITUS_TRAINING_ROLE
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="Loan Review Dashboard", layout="wide")
st.title("Loan Application Review Dashboard")
st.caption("Flagged applications requiring manual fraud review")

SCHEMA = session.sql("SELECT CURRENT_SCHEMA()").collect()[0][0]
DB = session.sql("SELECT CURRENT_DATABASE()").collect()[0][0]
FQ = f"{DB}.{SCHEMA}"

tab_review, tab_history = st.tabs(["Pending Review", "Review History"])

with tab_review:
    flagged_df = session.sql(f"""
        SELECT
            APPLICATION_ID,
            BUSINESS_NAME,
            INDUSTRY,
            LOAN_AMOUNT,
            RISK_TIER,
            ROUND(FRAUD_PROBABILITY * 100, 1) AS FRAUD_SCORE_PCT,
            PREDICTION,
            SCORED_AT
        FROM {FQ}.FLAGGED_FOR_REVIEW
        WHERE REVIEW_STATUS = 'PENDING'
        ORDER BY FRAUD_PROBABILITY DESC
    """).to_pandas()

    if flagged_df.empty:
        st.success("No pending applications to review.")
    else:
        st.metric("Pending Reviews", len(flagged_df))
        st.divider()

        for idx, row in flagged_df.iterrows():
            with st.expander(
                f"**{row['APPLICATION_ID']}** — {row['BUSINESS_NAME']} | "
                f"Fraud Score: {row['FRAUD_SCORE_PCT']}% | "
                f"${row['LOAN_AMOUNT']:,.2f}",
                expanded=(idx < 3)
            ):
                col1, col2, col3, col4 = st.columns(4)
                col1.metric("Loan Amount", f"${row['LOAN_AMOUNT']:,.2f}")
                col2.metric("Fraud Score", f"{row['FRAUD_SCORE_PCT']}%")
                col3.metric("Risk Tier", row['RISK_TIER'])
                col4.metric("Industry", row['INDUSTRY'])

                st.markdown("**Risk Factors:**")
                risk_factors = []
                if row['FRAUD_SCORE_PCT'] >= 80:
                    risk_factors.append("Very high fraud probability")
                if row['RISK_TIER'] == 'HIGH':
                    risk_factors.append("High risk tier classification")
                if row['LOAN_AMOUNT'] > 500000:
                    risk_factors.append("Large loan amount (>$500K)")
                if not risk_factors:
                    risk_factors.append("Moderate risk — review recommended")
                for rf in risk_factors:
                    st.markdown(f"- {rf}")

                st.caption(f"Scored at: {row['SCORED_AT']}")

                btn_col1, btn_col2 = st.columns(2)
                with btn_col1:
                    if st.button("Approve", key=f"approve_{row['APPLICATION_ID']}_{idx}"):
                        session.sql(f"""
                            UPDATE {FQ}.FLAGGED_FOR_REVIEW
                            SET REVIEW_STATUS = 'APPROVED',
                                REVIEWED_BY = CURRENT_USER(),
                                REVIEW_DATE = CURRENT_TIMESTAMP(),
                                REVIEW_DECISION = 'APPROVED'
                            WHERE APPLICATION_ID = '{row['APPLICATION_ID']}'
                            AND REVIEW_STATUS = 'PENDING'
                        """).collect()
                        st.success(f"Approved {row['APPLICATION_ID']}")
                        st.rerun()

                with btn_col2:
                    if st.button("Decline", key=f"decline_{row['APPLICATION_ID']}_{idx}"):
                        session.sql(f"""
                            UPDATE {FQ}.FLAGGED_FOR_REVIEW
                            SET REVIEW_STATUS = 'DECLINED',
                                REVIEWED_BY = CURRENT_USER(),
                                REVIEW_DATE = CURRENT_TIMESTAMP(),
                                REVIEW_DECISION = 'DECLINED'
                            WHERE APPLICATION_ID = '{row['APPLICATION_ID']}'
                            AND REVIEW_STATUS = 'PENDING'
                        """).collect()
                        st.warning(f"Declined {row['APPLICATION_ID']}")
                        st.rerun()

with tab_history:
    history_df = session.sql(f"""
        SELECT
            APPLICATION_ID,
            BUSINESS_NAME,
            LOAN_AMOUNT,
            ROUND(FRAUD_PROBABILITY * 100, 1) AS FRAUD_SCORE_PCT,
            REVIEW_STATUS,
            REVIEWED_BY,
            REVIEW_DATE,
            REVIEW_DECISION
        FROM {FQ}.FLAGGED_FOR_REVIEW
        WHERE REVIEW_STATUS != 'PENDING'
        ORDER BY REVIEW_DATE DESC
        LIMIT 100
    """).to_pandas()

    if history_df.empty:
        st.info("No reviews completed yet.")
    else:
        col1, col2, col3 = st.columns(3)
        col1.metric("Total Reviewed", len(history_df))
        col2.metric("Approved", len(history_df[history_df['REVIEW_DECISION'] == 'APPROVED']))
        col3.metric("Declined", len(history_df[history_df['REVIEW_DECISION'] == 'DECLINED']))
        st.dataframe(history_df, use_container_width=True)
